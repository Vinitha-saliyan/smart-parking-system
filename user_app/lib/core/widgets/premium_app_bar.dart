import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/utils/extensions.dart';

class PremiumAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double expandedHeight;
  final Widget? flexibleSpace;

  const PremiumAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.expandedHeight = 0,
    this.flexibleSpace,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: leading,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            centerTitle: flexibleSpace == null,
            title: flexibleSpace == null
                ? ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.primaryGradient.createShader(bounds),
                    child: Text(
                      title,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
            background: flexibleSpace != null
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isDark
                              ? Colors.black.withOpacity(0.4)
                              : Colors.white.withOpacity(0.8),
                          isDark
                              ? Colors.black.withOpacity(0.8)
                              : Colors.white.withOpacity(0.9),
                        ],
                      ),
                    ),
                    child: flexibleSpace,
                  )
                : Container(
                    color: isDark
                        ? Colors.black.withOpacity(0.7)
                        : Colors.white.withOpacity(0.7),
                  ),
          ),
        ),
      ),
      actions: actions,
    );
  }
}
