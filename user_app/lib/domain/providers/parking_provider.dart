import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_user/data/models/parking_area_model.dart';
import 'package:smart_parking_user/data/models/parking_slot_model.dart';
import 'package:smart_parking_user/data/repositories/parking_repository.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return ParkingRepository(ref.watch(apiServiceProvider));
});

final parkingAreasProvider =
    FutureProvider<List<ParkingAreaModel>>((ref) async {
  final repository = ref.watch(parkingRepositoryProvider);
  return repository.getAreas();
});

final parkingSlotsProvider =
    FutureProvider.family<List<ParkingSlotModel>, String>((ref, areaId) async {
  final repository = ref.watch(parkingRepositoryProvider);
  return repository.getSlotsByArea(areaId);
});

final areaSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, areaId) async {
  final repository = ref.watch(parkingRepositoryProvider);
  return repository.getAreaSummary(areaId);
});
