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
      _showMessage(_friendlyPaymentError(error), isError: true);
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
            : '₹10 advance verified. Your booking is confirmed.',
      );
      context.go('/reservations');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        'Payment was received, but confirmation is still pending. Please refresh your booking before trying again.',
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

  String _friendlyPaymentError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('not authenticated') ||
        message.contains('unauthorized')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (message.contains('razorpay') || message.contains('payment')) {
      return 'The payment service is temporarily unavailable. Please try again shortly.';
    }
    if (message.contains('connection') || message.contains('timeout')) {
      return 'Unable to connect to the payment service. Check your connection and try again.';
    }
    return 'Unable to start payment. Please try again.';
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isSettlement
                      ? Icons.receipt_long_outlined
                      : Icons.shield_outlined,
                  size: 48,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              isSettlement
                  ? 'Complete your checkout'
                  : 'Reserve your parking slot',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              isSettlement
                  ? 'The ₹10 advance has already been deducted. The slot becomes vacant only after this payment is verified.'
                  : 'Pay a non-refundable ₹10 advance. You then have 30 minutes to enter and start parking.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                height: 1.45,
              ),
            ),
            if (!isSettlement) ...[
              const SizedBox(height: 24),
              const _PaymentProgress(),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isSettlement ? 'Balance to pay' : 'Advance to pay'),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: isSettlement
                  ? 'Pay Final Balance Securely'
                  : 'Pay Securely with Razorpay',
              icon: Icons.payment,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _startCheckout,
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.success,
                  size: 17,
                ),
                SizedBox(width: 7),
                Text(
                  'Secure payment · Verified by backend',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (isSettlement) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : () => context.pop(),
                child: const Text('Return to booking'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentProgress extends StatelessWidget {
  const _PaymentProgress();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _step('1', 'Slot', true),
        _line(true),
        _step('2', 'Payment', true),
        _line(false),
        _step('3', 'Confirmed', false),
      ],
    );
  }

  Widget _line(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? AppColors.primary : AppColors.borderDark,
      ),
    );
  }

  Widget _step(String number, String label, bool active) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? AppColors.primary : AppColors.borderDark,
              ),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: active ? Colors.white : AppColors.textSecondaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
