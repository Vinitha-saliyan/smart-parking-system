import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/utils/validators.dart';
import 'package:smart_parking_user/core/widgets/glass_card.dart';
import 'package:smart_parking_user/core/widgets/gradient_button.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';
import 'package:smart_parking_user/ui/auth/widgets/auth_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(authRepositoryProvider)
            .forgotPassword(_emailController.text.trim());
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
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
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(height: 40),
                GlassCard(
                  padding: const EdgeInsets.all(24.0),
                  child: _isSuccess ? _buildSuccess() : _buildForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reset Password',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              color: Colors.white,
            ),
          ).animate().slideX(begin: -0.2, end: 0, duration: 400.ms).fadeIn(),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we will send you a link to reset your password.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          )
              .animate()
              .slideX(begin: -0.2, end: 0, delay: 100.ms, duration: 400.ms)
              .fadeIn(),
          const SizedBox(height: 32),
          AuthTextField(
            label: 'Email',
            prefixIcon: Icons.email_outlined,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.validateEmail,
          ).animate().slideY(begin: 0.2, end: 0, delay: 200.ms).fadeIn(),
          const SizedBox(height: 32),
          GradientButton(
            text: 'Send Reset Link',
            isLoading: _isLoading,
            onPressed: _sendResetLink,
          ).animate().slideY(begin: 0.2, end: 0, delay: 300.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check_circle, color: AppColors.success, size: 48),
          ),
        ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
        const SizedBox(height: 24),
        const Text(
          'Email Sent!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
            color: Colors.white,
          ),
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 16),
        Text(
          'We have sent a password reset link to ${_emailController.text}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ).animate().fadeIn(delay: 500.ms),
        const SizedBox(height: 32),
        GradientButton(
          text: 'Back to Login',
          onPressed: () => context.pop(),
        ).animate().fadeIn(delay: 700.ms),
      ],
    );
  }
}
