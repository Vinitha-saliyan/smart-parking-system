import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smart_parking_user/core/utils/extensions.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  static Widget card({double height = 150}) {
    return ShimmerLoading(
        width: double.infinity, height: height, borderRadius: 16);
  }

  static Widget listTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const ShimmerLoading(width: 50, height: 50, borderRadius: 25),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoading(width: double.infinity, height: 16),
                SizedBox(height: 8),
                ShimmerLoading(width: 150, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget grid({int crossAxisCount = 2, double childAspectRatio = 1.0}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) => const ShimmerLoading(
          width: double.infinity, height: double.infinity, borderRadius: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
