import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_parking_user/core/widgets/glass_card.dart';

class QrDisplay extends StatelessWidget {
  final String qrData;
  final String reservationId;

  const QrDisplay({
    super.key,
    required this.qrData,
    required this.reservationId,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Scan at Entry',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ID: $reservationId',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
