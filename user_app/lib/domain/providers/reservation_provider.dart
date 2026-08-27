import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_user/data/models/reservation_model.dart';
import 'package:smart_parking_user/data/repositories/reservation_repository.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepository(ref.watch(apiServiceProvider));
});

final activeReservationProvider =
    FutureProvider<ReservationModel?>((ref) async {
  final repository = ref.watch(reservationRepositoryProvider);
  return repository.getActiveReservation();
});

final reservationsListProvider =
    FutureProvider<List<ReservationModel>>((ref) async {
  final repository = ref.watch(reservationRepositoryProvider);
  return repository.getReservations();
});
