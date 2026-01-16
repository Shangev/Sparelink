import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/services/storage_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
  
  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Sign up with phone - this creates the user and sends OTP
      // Using a temporary password since we're using OTP-based auth
      await supabaseService.signUpWithPhone(
        phone: _phoneController.text.trim(),
        password: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      setState(() => _otpSent = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent! Check your phone (use 123456 for test numbers)'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } on AuthException catch (e) {
      // If user already exists, try to send OTP for login instead
      if (e.message.contains('already registered') || e.message.contains('already exists')) {
        try {
          final supabaseService = ref.read(supabaseServiceProvider);
          await supabaseService.signInWithOtp(phone: _phoneController.text.trim());
          setState(() => _otpSent = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account exists! OTP sent for login (use 123456 for test numbers)'),
                backgroundColor: AppTheme.accentGreen,
              ),
            );
          }
        } catch (loginError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send OTP: ${loginError.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
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
  
  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Verify OTP
      final response = await supabaseService.verifyOtp(
        phone: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
      );
      
      if (response.user != null) {
        // Check if profile is complete
        final profile = await supabaseService.getProfile(response.user!.id);
        final hasCompletedProfile = profile != null && 
            profile['full_name'] != null && 
            (profile['full_name'] as String).trim().isNotEmpty;
        
        if (mounted) {
          if (!hasCompletedProfile) {
            // New user - redirect to complete profile
            context.go('/complete-profile', extra: {
              'phone': _phoneController.text.trim(),
              'userId': response.user!.id,
            });
          } else {
            // Existing user with complete profile - go home
            final storageService = ref.read(storageServiceProvider);
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
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString()}'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryBlack,
              AppTheme.darkGray,
            ],
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
                  // Glass Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: AppTheme.glassDecoration(borderRadius: 20),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Join SpareLink',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your phone number to get started',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Phone Input
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
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                if (!value.startsWith('+')) {
                                  return 'Include country code (e.g., +27)';
                                }
                                return null;
                              },
                            ),
                            
                            // OTP Input (shown after OTP sent)
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
                                style: const TextStyle(
                                  letterSpacing: 8,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Test accounts use OTP: 123456',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.lightGray,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            
                            const SizedBox(height: 32),
                            
                            // Register / Verify Button
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading 
                                    ? null 
                                    : (_otpSent ? _handleVerifyOtp : _handleSendOtp),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(_otpSent ? 'Verify & Continue' : 'Send OTP'),
                              ),
                            ),
                            
                            // Resend OTP button
                            if (_otpSent) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _isLoading ? null : _handleSendOtp,
                                child: const Text(
                                  'Resend OTP',
                                  style: TextStyle(color: AppTheme.accentGreen),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: AppTheme.accentGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
