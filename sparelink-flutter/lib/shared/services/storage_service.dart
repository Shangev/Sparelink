import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage Service Provider for JWT tokens and user data
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  // Use FlutterSecureStorage for mobile, SharedPreferences for web
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  // Storage Keys
  static const String _keyToken = 'jwt_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserName = 'user_name';
  static const String _keyUserPhone = 'user_phone';
  
  // ============================================
  // PLATFORM-AWARE STORAGE METHODS
  // ============================================
  
  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }
  
  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _secureStorage.read(key: key);
    }
  }
  
  Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }
  
  Future<void> _deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserRole);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keyUserPhone);
    } else {
      await _secureStorage.deleteAll();
    }
  }
  
  // ============================================
  // TOKEN MANAGEMENT
  // ============================================
  
  /// Save JWT token
  Future<void> saveToken(String token) async {
    await _write(_keyToken, token);
  }
  
  /// Get JWT token
  Future<String?> getToken() async {
    return await _read(_keyToken);
  }
  
  /// Delete JWT token
  Future<void> deleteToken() async {
    await _delete(_keyToken);
  }
  
  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
  
  // ============================================
  // USER DATA MANAGEMENT
  // ============================================
  
  /// Save user data
  Future<void> saveUserData({
    required String userId,
    required String role,
    required String name,
    required String phone,
  }) async {
    await Future.wait([
      _write(_keyUserId, userId),
      _write(_keyUserRole, role),
      _write(_keyUserName, name),
      _write(_keyUserPhone, phone),
    ]);
  }
  
  /// Get user ID
  Future<String?> getUserId() async {
    return await _read(_keyUserId);
  }
  
  /// Get user role
  Future<String?> getUserRole() async {
    return await _read(_keyUserRole);
  }
  
  /// Get user name
  Future<String?> getUserName() async {
    return await _read(_keyUserName);
  }
  
  /// Save user name (for profile updates)
  Future<void> saveUserName(String name) async {
    await _write(_keyUserName, name);
  }
  
  /// Get user phone
  Future<String?> getUserPhone() async {
    return await _read(_keyUserPhone);
  }
  
  // ============================================
  // CLEAR ALL DATA (LOGOUT)
  // ============================================
  
  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    await _deleteAll();
  }
}
