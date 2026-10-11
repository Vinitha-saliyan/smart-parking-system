import 'package:flutter/material.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';

class YoloDashboardScreen extends StatelessWidget {
  const YoloDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YOLO AI Controls')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AdminCard(
          title: 'Model Status',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Model: YOLOv8 Nano'),
              const Text('Status: Loaded'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () {}, child: const Text('Start Detection')),
            ],
          ),
        ),
      ),
    );
  }
}
