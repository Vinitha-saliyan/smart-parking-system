class PaymentOrderModel {
  const PaymentOrderModel({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.keyId,
  });

  final String orderId;
  final int amount;
  final String currency;
  final String keyId;

  factory PaymentOrderModel.fromJson(Map<String, dynamic> json) {
    return PaymentOrderModel(
      orderId: json['order_id'] as String,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      keyId: json['key_id'] as String,
    );
  }
}
