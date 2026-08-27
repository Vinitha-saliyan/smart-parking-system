import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final authState = ref.read(authStateProvider);

    if (authState is AuthAuthenticated) {
      context.go('/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .fadeIn(duration: 500.ms)
                  .scale(
                    delay: 200.ms,
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: 32),
              const Text(
                'Smart Parking',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Outfit',
                ),
              )
                  .animate()
                  .slideY(
                    begin: 0.5,
                    end: 0,
                    delay: 400.ms,
                    duration: 500.ms,
                    curve: Curves.easeOut,
                  )
                  .fadeIn(
                    delay: 400.ms,
                    duration: 500.ms,
                  ),
              const SizedBox(height: 8),
              const Text(
                'AI-Powered',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.secondary,
                  letterSpacing: 2,
                  fontFamily: 'Inter',
                ),
              ).animate().fadeIn(
                    delay: 700.ms,
                    duration: 500.ms,
                  ),
              const SizedBox(height: 64),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? AppColors.primary
                          : (index == 1
                              ? AppColors.secondary
                              : AppColors.accent),
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(
                        onPlay: (controller) => controller.repeat(),
                      )
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.2, 1.2),
                        duration: 600.ms,
                        delay: (index * 200).ms,
                      )
                      .then(delay: 600.ms)
                      .scale(
                        begin: const Offset(1.2, 1.2),
                        end: const Offset(0.5, 0.5),
                        duration: 600.ms,
                      );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
