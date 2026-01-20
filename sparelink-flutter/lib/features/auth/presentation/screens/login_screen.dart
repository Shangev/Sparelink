import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/auth_responsive_layout.dart';
import '../../../../core/constants/environment_config.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/services/auth_service.dart';

/// Login method enum
enum LoginMethod { phone, email }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  LoginMethod _loginMethod = LoginMethod.phone;
  
  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkBiometricLogin();
  }
  
  Future<void> _loadSavedCredentials() async {
    final authService = ref.read(authServiceProvider);
    final savedEmail = await authService.getSavedEmail();
    if (savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
        _loginMethod = LoginMethod.email;
      });
    }
  }
  
  Future<void> _checkBiometricLogin() async {
    final authService = ref.read(authServiceProvider);
    final biometricEnabled = await authService.isBiometricLoginEnabled();
    
    if (biometricEnabled && authService.hasActiveSession()) {
      // Try biometric authentication
      final authenticated = await authService.authenticateWithBiometrics();
      if (authenticated && mounted) {
        context.go('/');
      }
    }
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _redirectToShopDashboard(String? accessToken) async {
    const shopDashboardUrl = EnvironmentConfig.shopDashboardUrl;
    
    if (kIsWeb) {
      final uri = Uri.parse('$shopDashboardUrl/dashboard?token=$accessToken');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        _showShopDashboardDialog(shopDashboardUrl);
      }
    } else {
      _showShopDashboardDialog(shopDashboardUrl);
    }
  }
  
  void _showShopDashboardDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        title: const Text('Shop Dashboard', style: TextStyle(color: Colors.white)),
        content: Text(
          'As a shop owner, please use the Shop Dashboard on your computer.\n\nVisit: $url',
          style: const TextStyle(color: AppTheme.lightGray),
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

  // Phone OTP Methods
  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      await supabaseService.signInWithOtp(phone: _phoneController.text.trim());
      
      setState(() => _otpSent = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent! Check your phone (use 123456 for test)'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP'), backgroundColor: Colors.red),
      );
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
        final profile = await supabaseService.getProfile(response.user!.id);
        final hasCompletedProfile = profile != null && 
            profile['full_name'] != null && 
            (profile['full_name'] as String).trim().isNotEmpty;
        
        if (!hasCompletedProfile) {
          if (mounted) {
            context.go('/complete-profile', extra: {
              'phone': _phoneController.text.trim(),
              'userId': response.user!.id,
            });
          }
          return;
        }
        
        await storageService.saveToken(response.session?.accessToken ?? '');
        await storageService.saveUserData(
          userId: response.user!.id,
          role: profile['role'] ?? 'mechanic',
          name: profile['full_name'] ?? '',
          phone: _phoneController.text.trim(),
        );
        
        if (mounted) {
          final userRole = profile['role'] ?? 'mechanic';
          if (userRole == 'shop') {
            await _redirectToShopDashboard(response.session?.accessToken);
          } else {
            context.go('/');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Email Login Method
  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      final supabaseService = ref.read(supabaseServiceProvider);
      
      final response = await authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );
      
      if (response.user != null) {
        final profile = await supabaseService.getProfile(response.user!.id);
        final hasCompletedProfile = profile != null && 
            profile['full_name'] != null && 
            (profile['full_name'] as String).trim().isNotEmpty;
        
        if (!hasCompletedProfile) {
          if (mounted) {
            context.go('/complete-profile', extra: {
              'email': _emailController.text.trim(),
              'userId': response.user!.id,
            });
          }
          return;
        }
        
        await storageService.saveToken(response.session?.accessToken ?? '');
        await storageService.saveUserData(
          userId: response.user!.id,
          role: profile['role'] ?? 'mechanic',
          name: profile['full_name'] ?? '',
          phone: profile['phone'] ?? '',
        );
        
        if (mounted) {
          final userRole = profile['role'] ?? 'mechanic';
          if (userRole == 'shop') {
            await _redirectToShopDashboard(response.session?.accessToken);
          } else {
            context.go('/');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Biometric Login
  Future<void> _handleBiometricLogin() async {
    final authService = ref.read(authServiceProvider);
    final status = await authService.checkBiometricStatus();
    
    if (status != BiometricStatus.available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    final authenticated = await authService.authenticateWithBiometrics();
    if (authenticated && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthResponsiveLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            _buildHeader(),
            const SizedBox(height: 40),
            _buildLoginMethodTabs(),
            const SizedBox(height: 24),
            _buildLoginCard(),
            const SizedBox(height: 24),
            _buildRegisterLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text('SpareLink', style: Theme.of(context).textTheme.displayLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Auto Parts Marketplace',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.lightGray),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginMethodTabs() {
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
              isSelected: _loginMethod == LoginMethod.phone,
              onTap: () => setState(() {
                _loginMethod = LoginMethod.phone;
                _otpSent = false;
              }),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'Email',
              icon: Icons.email,
              isSelected: _loginMethod == LoginMethod.email,
              onTap: () => setState(() {
                _loginMethod = LoginMethod.email;
              }),
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

  Widget _buildLoginCard() {
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
              Text('Welcome Back', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Login to continue', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              _loginMethod == LoginMethod.phone ? _buildPhoneLogin() : _buildEmailLogin(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneLogin() {
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
                : Text(_otpSent ? 'Verify & Login' : 'Send OTP'),
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

  Widget _buildEmailLogin() {
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
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your password';
            if (value.length < 6) return 'Password must be at least 6 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                activeColor: AppTheme.accentGreen,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Remember me', style: TextStyle(color: AppTheme.lightGray, fontSize: 14)),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/forgot-password', extra: _emailController.text),
              child: const Text('Forgot Password?', style: TextStyle(color: AppTheme.accentGreen, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleEmailLogin,
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Login'),
          ),
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          _buildBiometricButton(),
        ],
      ],
    );
  }

  Widget _buildBiometricButton() {
    return FutureBuilder<BiometricStatus>(
      future: ref.read(authServiceProvider).checkBiometricStatus(),
      builder: (context, snapshot) {
        if (snapshot.data != BiometricStatus.available) {
          return const SizedBox.shrink();
        }
        return OutlinedButton.icon(
          onPressed: _handleBiometricLogin,
          icon: const Icon(Icons.fingerprint, color: AppTheme.accentGreen),
          label: const Text('Login with Biometrics'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.accentGreen),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        );
      },
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: Theme.of(context).textTheme.bodyMedium),
        TextButton(
          onPressed: () => context.push('/register'),
          child: const Text('Register', style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
