import 'package:flutter/material.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Center')),
      body: const Center(child: Text('Notifications UI')),
    );
  }
}
