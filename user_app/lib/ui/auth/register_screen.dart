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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(
    String message, {
    Color backgroundColor = AppColors.error,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid) {
      return;
    }

    if (!_agreedToTerms) {
      _showMessage(
        'Please agree to Terms & Conditions',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage('Passwords do not match');
      return;
    }

    final authNotifier = ref.read(authStateProvider.notifier);

    final success = await authNotifier.register(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
      _phoneController.text.trim(),
    );

    // The screen might have been removed while registration was running.
    if (!mounted) return;

    final authState = ref.read(authStateProvider);

    if (authState is AuthError) {
      _showMessage(authState.message);
      return;
    }

    if (success) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch() automatically rebuilds the button when loading changes.
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
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                    onPressed: isLoading
                        ? null
                        : () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/login');
                            }
                          },
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create Account',
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
                        const SizedBox(height: 32),
                        AuthTextField(
                          label: 'Full Name',
                          prefixIcon: Icons.person_outline,
                          controller: _nameController,
                          validator: Validators.validateName,
                        )
                            .animate()
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 100.ms,
                            )
                            .fadeIn(),
                        const SizedBox(height: 16),
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
                          label: 'Phone Number',
                          prefixIcon: Icons.phone_outlined,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: Validators.validatePhone,
                        )
                            .animate()
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 300.ms,
                            )
                            .fadeIn(),
                        const SizedBox(height: 16),
                        AuthTextField(
                          label: 'Password',
                          prefixIcon: Icons.lock_outline,
                          controller: _passwordController,
                          isPassword: true,
                          validator: Validators.validatePassword,
                        )
                            .animate()
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 400.ms,
                            )
                            .fadeIn(),
                        const SizedBox(height: 16),
                        AuthTextField(
                          label: 'Confirm Password',
                          prefixIcon: Icons.lock_outline,
                          controller: _confirmPasswordController,
                          isPassword: true,
                          validator: Validators.validatePassword,
                        )
                            .animate()
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 500.ms,
                            )
                            .fadeIn(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _agreedToTerms,
                              onChanged: isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _agreedToTerms = value ?? false;
                                      });
                                    },
                              fillColor:
                                  WidgetStateProperty.resolveWith<Color?>(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppColors.primary;
                                  }

                                  return Colors.transparent;
                                },
                              ),
                              side: const BorderSide(
                                color: Colors.white,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'I agree to the Terms & Conditions and '
                                'Privacy Policy',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 600.ms),
                        const SizedBox(height: 24),
                        GradientButton(
                          text: 'Create Account',
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _register,
                        )
                            .animate()
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 700.ms,
                            )
                            .fadeIn(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
