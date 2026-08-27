import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/utils/extensions.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock notifications for UI display
    final mockNotifications = [
      {
        'title': 'Reservation Confirmed',
        'body': 'Your parking slot A01 at City Center is confirmed.',
        'time': DateTime.now().subtract(const Duration(minutes: 5)),
        'isRead': false,
        'type': 'success',
      },
      {
        'title': '15 Minutes Remaining',
        'body':
            'Your reservation will expire in 15 minutes. Please proceed to the parking area.',
        'time': DateTime.now().subtract(const Duration(hours: 1)),
        'isRead': true,
        'type': 'warning',
      },
      {
        'title': 'Welcome to Smart Parking!',
        'body': 'Enjoy seamless AI-powered parking experiences.',
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'isRead': true,
        'type': 'info',
      }
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: mockNotifications.length,
        itemBuilder: (context, index) {
          final notif = mockNotifications[index];
          final isRead = notif['isRead'] as bool;
          final time = notif['time'] as DateTime;

          IconData icon;
          Color iconColor;

          switch (notif['type']) {
            case 'success':
              icon = Icons.check_circle;
              iconColor = AppColors.success;
              break;
            case 'warning':
              icon = Icons.warning;
              iconColor = AppColors.warning;
              break;
            default:
              icon = Icons.info;
              iconColor = AppColors.primary;
          }

          return Dismissible(
            key: ValueKey(index),
            background: Container(
              color: AppColors.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            child: Container(
              color: isRead
                  ? Colors.transparent
                  : AppColors.primary.withOpacity(0.05),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif['title'] as String,
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(notif['body'] as String),
                    const SizedBox(height: 8),
                    Text(
                      time.timeAgo,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: Duration(milliseconds: 100 * index))
              .slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }
}
