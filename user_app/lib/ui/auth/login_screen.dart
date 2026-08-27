import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/utils/validators.dart';
import 'package:smart_parking_user/core/widgets/glass_card.dart';
import 'package:smart_parking_user/core/widgets/gradient_button.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';
import 'package:smart_parking_user/ui/auth/widgets/auth_text_field.dart';
import 'package:smart_parking_user/ui/auth/widgets/social_login_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    FocusScope.of(context).unfocus();

    // Read the notifier before the asynchronous operation.
    final authNotifier = ref.read(authStateProvider.notifier);

    try {
      final success = await authNotifier.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // The router may have already removed this screen.
      if (!mounted) return;

      if (success) {
        context.go('/dashboard');
        return;
      }

      // It is safe to use ref because mounted was checked above.
      final authState = ref.read(authStateProvider);

      if (authState is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState is AuthLoading;

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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'P',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ).animate().scale(
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 40),

                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                            color: Colors.white,
                          ),
                        )
                            .animate()
                            .slideX(
                              begin: -0.2,
                              end: 0,
                              duration: 400.ms,
                            )
                            .fadeIn(),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        )
                            .animate()
                            .slideX(
                              begin: -0.2,
                              end: 0,
                              delay: 100.ms,
                              duration: 400.ms,
                            )
                            .fadeIn(),
                        const SizedBox(height: 32),
                        AuthTextField(
                          label: 'Email',
                          prefixIcon: Icons.email_outlined,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.validateEmail,
                        )
                            .animate()
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 200.ms,
                            )
                            .fadeIn(),
                        const SizedBox(height: 16),
                        AuthTextField(
                          label: 'Password',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          controller: _passwordController,
                          validator: Validators.validatePassword,
                        )
                            .animate()
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 300.ms,
                            )
                            .fadeIn(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () => context.push('/forgot-password'),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: 24),
                        GradientButton(
                          text: 'Sign In',
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _login,
                        )
                            .animate()
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 500.ms,
                            )
                            .fadeIn(),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 600.ms),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SocialLoginButton(
                              icon: Icons.g_mobiledata,
                              iconColor: Colors.red,
                              onPressed: () {},
                            ),
                            const SizedBox(width: 24),
                            SocialLoginButton(
                              icon: Icons.apple,
                              iconColor: Colors.black,
                              onPressed: () {},
                            ),
                          ],
                        ).animate().scale(
                              delay: 700.ms,
                              duration: 400.ms,
                              curve: Curves.easeOutBack,
                            ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    GestureDetector(
                      onTap: isLoading ? null : () => context.push('/register'),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
