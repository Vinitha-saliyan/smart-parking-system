import 'package:smart_parking_admin/data/models/camera_model.dart';
import 'package:smart_parking_admin/data/models/parking_area_model.dart';
import 'package:smart_parking_admin/data/models/reservation_model.dart';
import 'package:smart_parking_admin/data/models/stats_model.dart';
import 'package:smart_parking_admin/data/models/user_model.dart';
import 'package:smart_parking_admin/data/services/api_service.dart';

class AdminRepository {
  AdminRepository(this._apiService);

  final ApiService _apiService;

  Future<StatsModel> getDashboardStats() async {
    try {
      final response = await _apiService.client.get<Map<String, dynamic>>(
        '/admin/stats',
      );
      return StatsModel.fromJson(response.data ?? const {});
    } catch (error) {
      throw StateError(ApiService.errorMessage(error));
    }
  }

  Future<List<UserModel>> getUsers(String search) async {
    try {
      final response = await _apiService.client.get<List<dynamic>>(
        '/admin/users',
        queryParameters: search.trim().isEmpty ? null : {'search': search.trim()},
      );
      return (response.data ?? const [])
          .map(
            (item) => UserModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (error) {
      throw StateError(ApiService.errorMessage(error));
    }
  }

  Future<List<ParkingAreaModel>> getParkingAreas() async {
    try {
      final response = await _apiService.client.get<List<dynamic>>(
        '/admin/areas',
      );
      return (response.data ?? const [])
          .map(
            (item) => ParkingAreaModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (error) {
      throw StateError(ApiService.errorMessage(error));
    }
  }

  Future<List<ReservationModel>> getAllReservations({String? status}) async {
    try {
      final response = await _apiService.client.get<List<dynamic>>(
        '/admin/reservations',
        queryParameters: status == null || status.isEmpty
            ? {'limit': 100}
            : {'status': status.toUpperCase(), 'limit': 100},
      );
      return (response.data ?? const [])
          .map(
            (item) => ReservationModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (error) {
      throw StateError(ApiService.errorMessage(error));
    }
  }

  Future<List<CameraModel>> getCameras() async {
    try {
      final response = await _apiService.client.get<List<dynamic>>(
        '/admin/cameras',
      );
      return (response.data ?? const [])
          .map(
            (item) => CameraModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (error) {
      throw StateError(ApiService.errorMessage(error));
    }
  }

  Future<void> setAreaActive(String areaId, bool isActive) async {
    try {
      await _apiService.client.put<void>(
        '/admin/areas/$areaId',
        data: {'is_active': isActive},
      );
    } catch (error) {
      throw StateError(ApiService.errorMessage(error));
    }
  }

  Future<void> setUserSuspended(String userId, bool suspended) async {
    try {
      await _apiService.client.put<void>(
        '/admin/users/$userId/suspend',
        queryParameters: {'suspend': suspended},
      );
    } catch (error) {
      throw StateError(ApiService.errorMessage(error));
    }
  }

  Future<void> forceCancelReservation(String reservationId) async {
    try {
      await _apiService.client.put<void>(
        '/admin/reservations/$reservationId/force-cancel',
      );
    } catch (error) {
      throw StateError(ApiService.errorMessage(error));
    }
  }
}
