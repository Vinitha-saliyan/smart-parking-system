import 'package:smart_parking_user/data/models/parking_area_model.dart';
import 'package:smart_parking_user/data/models/parking_slot_model.dart';
import 'package:smart_parking_user/data/services/api_service.dart';

class ParkingRepository {
  final ApiService _apiService;

  ParkingRepository(this._apiService);

  Future<List<ParkingAreaModel>> getAreas() async {
    final response = await _apiService.get('/parking/areas');
    final items = _extractList(response, 'parking areas');

    return items.map((item) {
      if (item is! Map) {
        throw AppException('Invalid parking area received');
      }

      return ParkingAreaModel.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  Future<ParkingAreaModel> getAreaById(
    String areaId,
  ) async {
    final response = await _apiService.get(
      '/parking/areas/$areaId',
    );

    return ParkingAreaModel.fromJson(
      _extractMap(response, 'parking area'),
    );
  }

  Future<List<ParkingSlotModel>> getSlotsByArea(
    String areaId, {
    int? floor,
  }) async {
    final query = floor == null
        ? null
        : <String, dynamic>{
            'floor': floor,
          };

    final response = await _apiService.get(
      '/parking/areas/$areaId/slots',
      queryParameters: query,
    );

    final items = _extractList(response, 'parking slots');

    return items.map((item) {
      if (item is! Map) {
        throw AppException('Invalid parking slot received');
      }

      return ParkingSlotModel.fromJson(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  Future<Map<String, dynamic>> getAreaSummary(
    String areaId,
  ) async {
    final response = await _apiService.get(
      '/parking/areas/$areaId/summary',
    );

    final floors = _extractList(
      response,
      'parking summary',
    ).map((item) {
      if (item is! Map) {
        throw AppException('Invalid floor summary received');
      }

      return Map<String, dynamic>.from(item);
    }).toList();

    var total = 0;
    var vacant = 0;
    var occupied = 0;
    var reserved = 0;

    for (final floor in floors) {
      total += _toInt(floor['total']);
      vacant += _toInt(floor['vacant']);
      occupied += _toInt(floor['occupied']);
      reserved += _toInt(floor['reserved']);
    }

    return {
      'floors': floors,
      'total': total,
      'vacant': vacant,
      'occupied': occupied,
      'reserved': reserved,
      'total_slots': total,
      'available_slots': vacant,
      'occupied_slots': occupied,
      'reserved_slots': reserved,
    };
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

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
