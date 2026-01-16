import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/services/storage_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
  
  /// Redirect shop owners to the Shop Dashboard
  Future<void> _redirectToShopDashboard(String? accessToken) async {
    // Shop Dashboard URL - pass token for SSO
    const shopDashboardUrl = 'http://localhost:3000';
    
    if (kIsWeb) {
      // On web, redirect to the shop dashboard with token in URL
      final uri = Uri.parse('$shopDashboardUrl/dashboard?token=$accessToken');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        // Fallback: show message with link
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.darkGray,
              title: const Text('Shop Dashboard', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'As a shop owner, please use the Shop Dashboard to manage your business.',
                    style: TextStyle(color: AppTheme.lightGray),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    shopDashboardUrl,
                    style: const TextStyle(color: AppTheme.accentGreen),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/');
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } else {
      // On mobile, show a message directing them to the web dashboard
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkGray,
            title: const Text('Shop Dashboard', style: TextStyle(color: Colors.white)),
            content: const Text(
              'As a shop owner, please use the Shop Dashboard on your computer to manage quotes, orders, and settings.\n\nVisit: http://localhost:3000',
              style: TextStyle(color: AppTheme.lightGray),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
  
  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Send OTP to phone number
      await supabaseService.signInWithOtp(
        phone: _phoneController.text.trim(),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: ${e.toString()}'),
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
      final storageService = ref.read(storageServiceProvider);
      
      // Verify OTP
      final response = await supabaseService.verifyOtp(
        phone: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
      );
      
      if (response.user != null) {
        // Get user profile
        final profile = await supabaseService.getProfile(response.user!.id);
        
        // Check if profile is complete (has full_name)
        final hasCompletedProfile = profile != null && 
            profile['full_name'] != null && 
            (profile['full_name'] as String).trim().isNotEmpty;
        
        if (!hasCompletedProfile) {
          // Profile not complete - redirect to complete profile screen
          if (mounted) {
            context.go('/complete-profile', extra: {
              'phone': _phoneController.text.trim(),
              'userId': response.user!.id,
            });
          }
          return;
        }
        
        // Profile is complete - save user data locally
        await storageService.saveToken(response.session?.accessToken ?? '');
        await storageService.saveUserData(
          userId: response.user!.id,
          role: profile['role'] ?? 'mechanic',
          name: profile['full_name'] ?? '',
          phone: _phoneController.text.trim(),
        );
        
        if (mounted) {
          final userRole = profile['role'] ?? 'mechanic';
          
          // If user is a shop, redirect to shop dashboard
          if (userRole == 'shop') {
            await _redirectToShopDashboard(response.session?.accessToken);
          } else {
            // Navigate to home for mechanics
            context.go('/');
          }
        }
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
                  const SizedBox(height: 60),
                  
                  // Logo/Title
                  Text(
                    'SpareLink',
                    style: Theme.of(context).textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Auto Parts Marketplace',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 60),
                  
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
                              'Welcome Back',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Login to continue',
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
                            
                            const SizedBox(height: 24),
                            
                            // Send OTP / Verify Button
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
                                    : Text(_otpSent ? 'Verify & Login' : 'Send OTP'),
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
                  
                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text(
                          'Register',
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
