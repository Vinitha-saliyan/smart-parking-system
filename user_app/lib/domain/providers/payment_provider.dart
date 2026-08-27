import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_user/data/repositories/payment_repository.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiServiceProvider));
});
