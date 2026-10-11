import 'package:smart_parking_user/data/models/reservation_model.dart';
import 'package:smart_parking_user/data/services/api_service.dart';

class ReservationRepository {
  final ApiService _apiService;

  ReservationRepository(this._apiService);

  Future<ReservationModel> createReservation(
    String slotId,
    String areaId,
    DateTime startTime,
    DateTime endTime,
    String vehicleNumber,
  ) async {
    final response = await _apiService.post(
      '/reservations/',
      data: {
        'slot_id': slotId,
        'parking_area_id': areaId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'vehicle_number': vehicleNumber,
      },
    );

    return ReservationModel.fromJson(
      _extractMap(response, 'reservation'),
    );
  }

  Future<List<ReservationModel>> getReservations({
    String? status,
  }) async {
    final query = status == null
        ? null
        : <String, dynamic>{
            'status': status,
          };

    final response = await _apiService.get(
      '/reservations/',
      queryParameters: query,
    );

    final items = _extractList(
      response,
      'reservations',
    );

    return items.map((item) {
      if (item is! Map) {
        throw AppException('Invalid reservation received');
      }

      return ReservationModel.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  Future<ReservationModel?> getActiveReservation() async {
    final response = await _apiService.get(
      '/reservations/active',
    );

    if (response == null) {
      return null;
    }

    if (response is Map &&
        response.containsKey('data') &&
        response['data'] == null) {
      return null;
    }

    return ReservationModel.fromJson(
      _extractMap(response, 'active reservation'),
    );
  }

  Future<ReservationModel> getReservationById(
    String id,
  ) async {
    final response = await _apiService.get(
      '/reservations/$id',
    );

    return ReservationModel.fromJson(
      _extractMap(response, 'reservation'),
    );
  }

  Future<ReservationModel> cancelReservation(
    String id,
  ) async {
    final response = await _apiService.put(
      '/reservations/$id/cancel',
    );

    return ReservationModel.fromJson(
      _extractMap(response, 'reservation'),
    );
  }

  Future<ReservationModel> checkIn(
    String id,
  ) async {
    final response = await _apiService.put(
      '/reservations/$id/check-in',
    );

    return ReservationModel.fromJson(
      _extractMap(response, 'reservation'),
    );
  }

  Future<ReservationModel> checkOut(
    String id,
  ) async {
    final response = await _apiService.put(
      '/reservations/$id/check-out',
    );

    return ReservationModel.fromJson(
      _extractMap(response, 'reservation'),
    );
  }

  List<dynamic> _extractList(
    dynamic response,
    String label,
  ) {
    if (response is List) {
      return response;
    }

    if (response is Map) {
      final data = response['data'];

      if (data is List) {
        return data;
      }

      final items = response['items'];

      if (items is List) {
        return items;
      }
    }

    throw AppException('Invalid $label response from server');
  }

  Map<String, dynamic> _extractMap(
    dynamic response,
    String label,
  ) {
    if (response is Map) {
      final data = response['data'];

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return Map<String, dynamic>.from(response);
    }

    throw AppException('Invalid $label response from server');
  }
}
