import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_user/data/models/notification_model.dart';
import 'package:smart_parking_user/data/repositories/notification_repository.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiServiceProvider));
});

final notificationsProvider = FutureProvider<List<NotificationModel>>((ref) {
  return ref.watch(notificationRepositoryProvider).getNotifications();
});

final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (notifications) => notifications.any((item) => !item.isRead),
        orElse: () => false,
      );
});
