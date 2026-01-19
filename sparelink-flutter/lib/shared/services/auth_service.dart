import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';
import 'audit_logging_service.dart';
import '../../core/constants/environment_config.dart';

/// Enhanced Authentication Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final storageService = ref.read(storageServiceProvider);
  final auditLogger = ref.read(auditLoggerProvider);
  return AuthService(storageService, auditLogger);
});

/// Biometric availability state
enum BiometricStatus {
  available,
  notAvailable,
  notEnrolled,
  lockedOut,
}

/// Authentication Service
/// 
/// Provides comprehensive authentication features:
/// - Phone/OTP login (existing)
/// - Email/Password login (new)
/// - Password reset flow (new)
/// - Biometric authentication (new)
/// - Remember me functionality (new)
/// - Email verification (new)
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final StorageService _storageService;
  final AuditLoggingService _auditLogger;
  
  // Storage keys for auth preferences
  static const String _keyRememberMe = 'auth_remember_me';
  static const String _keyBiometricEnabled = 'auth_biometric_enabled';
  static const String _keySavedEmail = 'auth_saved_email';
  static const String _keyLastLoginMethod = 'auth_last_login_method';
  
  AuthService(this._storageService, this._auditLogger);
  
  // ===========================================
  // EMAIL/PASSWORD AUTHENTICATION
  // ===========================================
  
  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
        emailRedirectTo: EnvironmentConfig.isProduction 
            ? 'https://sparelink.co.za/auth/callback'
            : null,
      );
      
      await _auditLogger.logAuth(
        eventType: AuditEventType.authRegister,
        description: 'User registered with email',
        success: response.user != null,
      );
      
      return response;
    } catch (e) {
      await _auditLogger.logAuth(
        eventType: AuditEventType.authRegister,
        description: 'Email registration failed: $e',
        success: false,
      );
      rethrow;
    }
  }
  
  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Save remember me preference
        if (rememberMe) {
          await _saveRememberMe(email);
        }
        await _saveLastLoginMethod('email');
        
        await _auditLogger.logAuth(
          eventType: AuditEventType.authLogin,
          description: 'User logged in with email',
          success: true,
        );
      }
      
      return response;
    } catch (e) {
      await _auditLogger.logAuth(
        eventType: AuditEventType.authLogin,
        description: 'Email login failed: $e',
        success: false,
      );
      rethrow;
    }
  }
  
  /// Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      // Try to send password reset - if user doesn't exist, it will fail silently
      // This is a workaround since Supabase doesn't have a direct check
      await _supabase.auth.resetPasswordForEmail(email);
      return true; // If no error, email exists
    } catch (e) {
      return false;
    }
  }
  
  // ===========================================
  // PASSWORD RESET
  // ===========================================
  
  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: EnvironmentConfig.isProduction
            ? 'https://sparelink.co.za/auth/reset-password'
            : null,
      );
      
      await _auditLogger.logAuth(
        eventType: AuditEventType.authPasswordReset,
        description: 'Password reset email sent',
        success: true,
      );
    } catch (e) {
      await _auditLogger.logAuth(
        eventType: AuditEventType.authPasswordReset,
        description: 'Password reset email failed: $e',
        success: false,
      );
      rethrow;
    }
  }
  
  /// Update password (after clicking reset link)
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      await _auditLogger.logAuth(
        eventType: AuditEventType.authPasswordReset,
        description: 'Password updated successfully',
        success: true,
      );
    } catch (e) {
      await _auditLogger.logAuth(
        eventType: AuditEventType.authPasswordReset,
        description: 'Password update failed: $e',
        success: false,
      );
      rethrow;
    }
  }
  
  // ===========================================
  // EMAIL VERIFICATION
  // ===========================================
  
  /// Resend verification email
  Future<void> resendVerificationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      
      await _auditLogger.log(
        eventType: AuditEventType.authOtpRequest,
        description: 'Verification email resent',
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Check if current user's email is verified
  bool isEmailVerified() {
    final user = _supabase.auth.currentUser;
    return user?.emailConfirmedAt != null;
  }
  
  /// Get email confirmation status
  DateTime? getEmailConfirmedAt() {
    final confirmedAt = _supabase.auth.currentUser?.emailConfirmedAt;
    if (confirmedAt == null) return null;
    return DateTime.tryParse(confirmedAt);
  }
  
  // ===========================================
  // BIOMETRIC AUTHENTICATION
  // ===========================================
  
  /// Check if biometric authentication is available
  Future<BiometricStatus> checkBiometricStatus() async {
    if (kIsWeb) {
      return BiometricStatus.notAvailable;
    }
    
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!isAvailable || !isDeviceSupported) {
        return BiometricStatus.notAvailable;
      }
      
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return BiometricStatus.notEnrolled;
      }
      
      return BiometricStatus.available;
    } on PlatformException catch (e) {
      if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        return BiometricStatus.lockedOut;
      }
      return BiometricStatus.notAvailable;
    }
  }
  
  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to access SpareLink',
  }) async {
    if (kIsWeb) return false;
    
    try {
      final status = await checkBiometricStatus();
      if (status != BiometricStatus.available) {
        return false;
      }
      
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (didAuthenticate) {
        await _auditLogger.logAuth(
          eventType: AuditEventType.authLogin,
          description: 'User authenticated with biometrics',
          success: true,
        );
      }
      
      return didAuthenticate;
    } on PlatformException catch (e) {
      await _auditLogger.logAuth(
        eventType: AuditEventType.authLogin,
        description: 'Biometric authentication failed: ${e.message}',
        success: false,
      );
      return false;
    }
  }
  
  /// Enable biometric login for current user
  Future<void> enableBiometricLogin() async {
    await _storageService.saveBool(_keyBiometricEnabled, true);
  }
  
  /// Disable biometric login
  Future<void> disableBiometricLogin() async {
    await _storageService.saveBool(_keyBiometricEnabled, false);
  }
  
  /// Check if biometric login is enabled
  Future<bool> isBiometricLoginEnabled() async {
    return await _storageService.getBool(_keyBiometricEnabled) ?? false;
  }
  
  // ===========================================
  // REMEMBER ME FUNCTIONALITY
  // ===========================================
  
  /// Save remember me preference
  Future<void> _saveRememberMe(String email) async {
    await _storageService.saveBool(_keyRememberMe, true);
    await _storageService.saveString(_keySavedEmail, email);
  }
  
  /// Clear remember me
  Future<void> clearRememberMe() async {
    await _storageService.saveBool(_keyRememberMe, false);
    await _storageService.deleteKey(_keySavedEmail);
  }
  
  /// Get saved email (if remember me is enabled)
  Future<String?> getSavedEmail() async {
    final rememberMe = await _storageService.getBool(_keyRememberMe) ?? false;
    if (rememberMe) {
      return await _storageService.getString(_keySavedEmail);
    }
    return null;
  }
  
  /// Check if remember me is enabled
  Future<bool> isRememberMeEnabled() async {
    return await _storageService.getBool(_keyRememberMe) ?? false;
  }
  
  // ===========================================
  // SESSION MANAGEMENT
  // ===========================================
  
  /// Save last login method
  Future<void> _saveLastLoginMethod(String method) async {
    await _storageService.saveString(_keyLastLoginMethod, method);
  }
  
  /// Get last login method
  Future<String?> getLastLoginMethod() async {
    return await _storageService.getString(_keyLastLoginMethod);
  }
  
  /// Check if user has active session
  bool hasActiveSession() {
    return _supabase.auth.currentSession != null;
  }
  
  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;
  
  /// Get current session
  Session? get currentSession => _supabase.auth.currentSession;
  
  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      await _storageService.clearAll();
      
      await _auditLogger.logAuth(
        eventType: AuditEventType.authLogout,
        description: 'User signed out',
        success: true,
      );
    } catch (e) {
      await _auditLogger.logAuth(
        eventType: AuditEventType.authLogout,
        description: 'Sign out failed: $e',
        success: false,
      );
      rethrow;
    }
  }
  
  /// Refresh session
  Future<AuthResponse> refreshSession() async {
    final response = await _supabase.auth.refreshSession();
    return response;
  }
}
