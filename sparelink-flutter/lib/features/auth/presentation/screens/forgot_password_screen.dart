import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/auth_service.dart';
import '../widgets/auth_responsive_layout.dart';

/// Forgot Password Screen
/// 
/// Allows users to request a password reset email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? email;
  
  const ForgotPasswordScreen({super.key, this.email});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
  
  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendPasswordResetEmail(_emailController.text.trim());
      
      setState(() => _emailSent = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AuthResponsiveLayout(
      showBackButton: true,
      title: 'Reset Password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            
            // Icon
            const Icon(
              Icons.lock_reset,
              size: 80,
              color: AppTheme.accentGreen,
            ),
            
            const SizedBox(height: 24),
            
            // Glass Card
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: AppTheme.glassDecoration(borderRadius: 20),
                  padding: const EdgeInsets.all(24),
                  child: _emailSent 
                      ? _buildSuccessContent()
                      : _buildFormContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Forgot Your Password?',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email address and we\'ll send you a link to reset your password.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),
        
        // Email Input
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'your@email.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 24),
        
        // Send Reset Email Button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleResetPassword,
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Send Reset Link'),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Back to login
        TextButton(
          onPressed: () => context.pop(),
          child: const Text(
            'Back to Login',
            style: TextStyle(color: AppTheme.lightGray),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSuccessContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read,
          size: 60,
          color: AppTheme.accentGreen,
        ),
        const SizedBox(height: 16),
        Text(
          'Check Your Email',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a password reset link to:',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _emailController.text,
          style: const TextStyle(
            color: AppTheme.accentGreen,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          'Click the link in the email to reset your password. '
          'If you don\'t see it, check your spam folder.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        
        // Resend button
        OutlinedButton(
          onPressed: _isLoading ? null : _handleResetPassword,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.accentGreen),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resend Email'),
        ),
        
        const SizedBox(height: 16),
        
        // Back to login
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to Login'),
          ),
        ),
      ],
    );
  }
}
