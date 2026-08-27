import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/widgets/gradient_button.dart';
import 'package:smart_parking_user/data/models/payment_order_model.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';
import 'package:smart_parking_user/domain/providers/payment_provider.dart';
import 'package:smart_parking_user/domain/providers/reservation_provider.dart';

class PaymentScreenArgs {
  const PaymentScreenArgs({
    required this.reservationId,
    required this.amountPaise,
    this.currency = 'INR',
    this.purpose = 'ADVANCE',
  });

  final String reservationId;
  final int amountPaise;
  final String currency;
  final String purpose;

  bool get isSettlement => purpose == 'SETTLEMENT';
}

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.args});

  final PaymentScreenArgs args;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late final Razorpay _razorpay;
  PaymentOrderModel? _activeOrder;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    if (widget.args.amountPaise < 100) {
      _showMessage('Payment amount must be at least ₹1.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final order = await ref.read(paymentRepositoryProvider).createOrder(
            reservationId: widget.args.reservationId,
            amount: widget.args.amountPaise,
            currency: widget.args.currency,
            purpose: widget.args.purpose,
          );
      if (!mounted) return;

      _activeOrder = order;
      final user = ref.read(currentUserProvider);
      final options = <String, dynamic>{
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amount,
        'currency': order.currency,
        'name': 'Smart Parking',
        'description': widget.args.isSettlement
            ? 'Final parking balance'
            : '₹10 reservation advance',
        'prefill': {
          'email': user?.email ?? '',
          'contact': user?.phone ?? '',
        },
        'retry': {'enabled': true, 'max_count': 3},
        'theme': {'color': '#2563EB'},
      };

      setState(() => _isLoading = false);
      _razorpay.open(options);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId;
    final orderId = response.orderId ?? _activeOrder?.orderId;
    final signature = response.signature;
    if (paymentId == null || orderId == null || signature == null) {
      _showMessage(
        'Razorpay returned incomplete payment details.',
        isError: true,
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    try {
      await ref.read(paymentRepositoryProvider).verifyPayment(
            paymentId: paymentId,
            orderId: orderId,
            signature: signature,
          );
      ref.invalidate(activeReservationProvider);
      ref.invalidate(reservationsListProvider);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        widget.args.isSettlement
            ? 'Final payment verified. Checkout is complete.'
            : '₹10 advance verified. Your parking QR is ready.',
      );
      context.go('/reservations');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        'Payment was received but verification failed: $error',
        isError: true,
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) setState(() => _isLoading = false);
    final cancelled = response.code == Razorpay.PAYMENT_CANCELLED;
    final cancellationMessage = widget.args.isSettlement
        ? 'Payment cancelled. Checkout remains pending and the slot stays occupied.'
        : 'Payment cancelled. The slot remains held until the 30-minute timer expires.';
    _showMessage(
      cancelled
          ? cancellationMessage
          : 'Payment failed: ${response.message ?? 'Please try again.'}',
      isError: !cancelled,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showMessage(
      'External wallet selected: ${response.walletName ?? 'wallet'}',
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.args.amountPaise / 100;
    final isSettlement = widget.args.isSettlement;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSettlement ? 'Final Payment' : 'Reservation Advance'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              isSettlement
                  ? 'Complete your checkout'
                  : 'Reserve your parking slot',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              isSettlement
                  ? 'The ₹10 advance has already been deducted. The slot becomes vacant only after this payment is verified.'
                  : 'Pay a non-refundable ₹10 advance. You then have 30 minutes to enter and start parking.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isSettlement ? 'Balance to pay' : 'Advance to pay'),
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              text: 'Pay with Razorpay',
              icon: Icons.payment,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _startCheckout,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : () => context.pop(),
              child: Text(
                isSettlement
                    ? 'Return to booking'
                    : 'Pay later (before hold expires)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
