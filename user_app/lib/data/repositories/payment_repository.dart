import 'package:smart_parking_user/data/models/payment_order_model.dart';
import 'package:smart_parking_user/data/services/api_service.dart';

class PaymentRepository {
  PaymentRepository(this._apiService);

  final ApiService _apiService;

  Future<PaymentOrderModel> createOrder({
    required String reservationId,
    required int amount,
    String currency = 'INR',
    String purpose = 'ADVANCE',
  }) async {
    final response = await _apiService.post(
      '/payments/create-order',
      data: {
        'reservation_id': reservationId,
        'amount': amount,
        'currency': currency,
        'purpose': purpose,
      },
    );

    return PaymentOrderModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    await _apiService.post(
      '/payments/verify-payment',
      data: {
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'razorpay_signature': signature,
      },
    );
  }
}
