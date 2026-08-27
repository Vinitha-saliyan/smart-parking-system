import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
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
    final imageUrl = area.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : 310.0;
        return Container(
          width: cardWidth,
          height: 272,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 112,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  image: hasImage
                      ? DecorationImage(
                          image: NetworkImage(imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasImage
                    ? const Center(
                        child: Icon(Icons.local_parking,
                            size: 48, color: Colors.grey))
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
                      const Spacer(),
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
                          const Text(
                            '₹20/hr',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('View Slots'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
