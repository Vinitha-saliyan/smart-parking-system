import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/widgets/glass_card.dart';
import 'package:smart_parking_user/data/models/parking_area_model.dart';
import 'package:smart_parking_user/core/utils/extensions.dart';

class NearbyParkingCard extends StatelessWidget {
  final ParkingAreaModel area;
  final VoidCallback onTap;

  const NearbyParkingCard({
    super.key,
    required this.area,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey.shade300,
                  image: area.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(area.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: area.imageUrl == null
                    ? const Center(
                        child: Icon(Icons.local_parking,
                            size: 48, color: Colors.grey))
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.name,
                      style: context.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      area.address,
                      style: context.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${area.availableSlots} available',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '₹20 first hour',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
