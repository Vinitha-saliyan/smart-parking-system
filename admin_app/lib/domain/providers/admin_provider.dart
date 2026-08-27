import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_admin/data/models/camera_model.dart';
import 'package:smart_parking_admin/data/models/parking_area_model.dart';
import 'package:smart_parking_admin/data/models/reservation_model.dart';
import 'package:smart_parking_admin/data/models/stats_model.dart';
import 'package:smart_parking_admin/data/models/user_model.dart';
import 'package:smart_parking_admin/data/repositories/admin_repository.dart';
import 'package:smart_parking_admin/domain/providers/auth_provider.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiServiceProvider));
});

final dashboardStatsProvider = FutureProvider<StatsModel>((ref) {
  return ref.watch(adminRepositoryProvider).getDashboardStats();
});

final parkingAreasProvider = FutureProvider<List<ParkingAreaModel>>((ref) {
  return ref.watch(adminRepositoryProvider).getParkingAreas();
});

final usersProvider =
    FutureProvider.family<List<UserModel>, String>((ref, search) {
  return ref.watch(adminRepositoryProvider).getUsers(search);
});

final reservationsProvider =
    FutureProvider.family<List<ReservationModel>, String>((ref, status) {
  return ref.watch(adminRepositoryProvider).getAllReservations(
        status: status.isEmpty ? null : status,
      );
});

final camerasProvider = FutureProvider<List<CameraModel>>((ref) {
  return ref.watch(adminRepositoryProvider).getCameras();
});
