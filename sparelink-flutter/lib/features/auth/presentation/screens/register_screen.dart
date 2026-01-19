import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/terms_conditions_checkbox.dart';

/// Registration method enum
enum RegisterMethod { phone, email }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  bool _termsAccepted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _termsError;
  RegisterMethod _registerMethod = RegisterMethod.phone;
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  // Phone Registration
  Future<void> _handleSendOtp() async {
    // Validate terms first
    if (!_termsAccepted) {
      setState(() => _termsError = 'You must accept the Terms & Conditions');
      return;
    }
    setState(() => _termsError = null);
    
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      await supabaseService.signUpWithPhone(
        phone: _phoneController.text.trim(),
        password: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      setState(() => _otpSent = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent! Check your phone (use 123456 for test)'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } on AuthException catch (e) {
      if (e.message.contains('already registered') || e.message.contains('already exists')) {
        try {
          final supabaseService = ref.read(supabaseServiceProvider);
          await supabaseService.signInWithOtp(phone: _phoneController.text.trim());
          setState(() => _otpSent = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account exists! OTP sent for login'),
                backgroundColor: AppTheme.accentGreen,
              ),
            );
          }
        } catch (loginError) {
          _showError('Failed to send OTP: $loginError');
        }
      } else {
        _showError('Registration failed: ${e.message}');
      }
    } catch (e) {
      _showError('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.isEmpty) {
      _showError('Please enter the OTP');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      
      final response = await supabaseService.verifyOtp(
        phone: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
      );
      
      if (response.user != null) {
        // Save that terms were accepted
        await storageService.saveTermsAccepted();
        
        final profile = await supabaseService.getProfile(response.user!.id);
        final hasCompletedProfile = profile != null && 
            profile['full_name'] != null && 
            (profile['full_name'] as String).trim().isNotEmpty;
        
        if (mounted) {
          if (!hasCompletedProfile) {
            context.go('/complete-profile', extra: {
              'phone': _phoneController.text.trim(),
              'userId': response.user!.id,
            });
          } else {
            await storageService.saveToken(response.session?.accessToken ?? '');
            await storageService.saveUserData(
              userId: response.user!.id,
              role: profile['role'] ?? 'mechanic',
              name: profile['full_name'] ?? '',
              phone: _phoneController.text.trim(),
            );
            context.go('/');
          }
        }
      }
    } catch (e) {
      _showError('Verification failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Email Registration
  Future<void> _handleEmailRegister() async {
    // Validate terms first
    if (!_termsAccepted) {
      setState(() => _termsError = 'You must accept the Terms & Conditions');
      return;
    }
    setState(() => _termsError = null);
    
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      
      final response = await authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (response.user != null) {
        // Save that terms were accepted
        await storageService.saveTermsAccepted();
        
        if (mounted) {
          // Check if email confirmation is required
          if (response.user!.emailConfirmedAt == null) {
            _showEmailVerificationDialog();
          } else {
            context.go('/complete-profile', extra: {
              'email': _emailController.text.trim(),
              'userId': response.user!.id,
            });
          }
        }
      }
    } catch (e) {
      _showError('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        title: const Text('Verify Your Email', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread, size: 60, color: AppTheme.accentGreen),
            const SizedBox(height: 16),
            Text(
              'We\'ve sent a verification link to:\n${_emailController.text}',
              style: const TextStyle(color: AppTheme.lightGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please check your email and click the link to verify your account.',
              style: TextStyle(color: AppTheme.lightGray, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.resendVerificationEmail(_emailController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verification email resent!'),
                    backgroundColor: AppTheme.accentGreen,
                  ),
                );
              }
            },
            child: const Text('Resend Email'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryBlack, AppTheme.darkGray],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMethodTabs(),
                  const SizedBox(height: 24),
                  _buildRegistrationCard(),
                  const SizedBox(height: 24),
                  _buildLoginLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Phone',
              icon: Icons.phone,
              isSelected: _registerMethod == RegisterMethod.phone,
              onTap: () => setState(() {
                _registerMethod = RegisterMethod.phone;
                _otpSent = false;
              }),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'Email',
              icon: Icons.email,
              isSelected: _registerMethod == RegisterMethod.email,
              onTap: () => setState(() => _registerMethod = RegisterMethod.email),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.black : AppTheme.lightGray),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppTheme.lightGray,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: AppTheme.glassDecoration(borderRadius: 20),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Join SpareLink', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _registerMethod == RegisterMethod.phone
                    ? 'Enter your phone number to get started'
                    : 'Create your account with email',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _registerMethod == RegisterMethod.phone ? _buildPhoneRegistration() : _buildEmailRegistration(),
              const SizedBox(height: 24),
              TermsConditionsCheckbox(
                isChecked: _termsAccepted,
                onChanged: (value) => setState(() {
                  _termsAccepted = value ?? false;
                  if (_termsAccepted) _termsError = null;
                }),
                errorText: _termsError,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneRegistration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: !_otpSent,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '+27710000000',
            prefixIcon: const Icon(Icons.phone),
            suffixIcon: _otpSent
                ? IconButton(
                    icon: const Icon(Icons.edit, color: AppTheme.accentGreen),
                    onPressed: () => setState(() => _otpSent = false),
                  )
                : null,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your phone number';
            if (!value.startsWith('+')) return 'Include country code (e.g., +27)';
            return null;
          },
        ),
        if (_otpSent) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OTP sent to ${_phoneController.text}',
                    style: const TextStyle(color: AppTheme.accentGreen, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Enter OTP',
              hintText: '123456',
              prefixIcon: Icon(Icons.lock_outline),
              counterText: '',
            ),
            style: const TextStyle(letterSpacing: 8, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : (_otpSent ? _handleVerifyOtp : _handleSendOtp),
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_otpSent ? 'Verify & Continue' : 'Send OTP'),
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : _handleSendOtp,
            child: const Text('Resend OTP', style: TextStyle(color: AppTheme.accentGreen)),
          ),
        ],
      ],
    );
  }

  Widget _buildEmailRegistration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'your@email.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your email';
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Min. 8 characters',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter a password';
            if (value.length < 8) return 'Password must be at least 8 characters';
            if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include at least one uppercase letter';
            if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least one number';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Re-enter your password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please confirm your password';
            if (value != _passwordController.text) return 'Passwords do not match';
            return null;
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Password must contain: 8+ characters, 1 uppercase, 1 number',
          style: TextStyle(color: AppTheme.lightGray, fontSize: 12),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleEmailRegister,
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Create Account'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ', style: Theme.of(context).textTheme.bodyMedium),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Login', style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
