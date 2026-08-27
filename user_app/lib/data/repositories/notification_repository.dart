import 'package:smart_parking_user/data/models/notification_model.dart';
import 'package:smart_parking_user/data/services/api_service.dart';

class NotificationRepository {
  final ApiService _apiService;

  NotificationRepository(this._apiService);

  Future<List<NotificationModel>> getNotifications() async {
    final response = await _apiService.get('/notifications');
    return (response['data'] as List)
        .map((json) => NotificationModel.fromJson(json))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    await _apiService.put('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _apiService.put('/notifications/read-all');
  }
}
