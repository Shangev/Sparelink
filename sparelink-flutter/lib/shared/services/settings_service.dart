import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Settings Service - Persists user preferences locally and syncs with Supabase
class SettingsService extends ChangeNotifier {
  // Storage Keys
  static const String _keyDarkMode = 'settings_dark_mode';
  static const String _keyNotificationsEnabled = 'settings_notifications_enabled';
  static const String _keySoundEnabled = 'settings_sound_enabled';
  static const String _keyVibrationEnabled = 'settings_vibration_enabled';
  static const String _keyLocationEnabled = 'settings_location_enabled';
  static const String _keyLanguage = 'settings_language';
  static const String _keySavedAddresses = 'settings_saved_addresses';
  
  // Default values
  bool _darkMode = true;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _locationEnabled = false;
  String _language = 'en';
  List<SavedAddress> _savedAddresses = [];
  bool _isLoaded = false;
  
  // Getters
  bool get darkMode => _darkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get locationEnabled => _locationEnabled;
  String get language => _language;
  List<SavedAddress> get savedAddresses => List.unmodifiable(_savedAddresses);
  bool get isLoaded => _isLoaded;
  
  /// Load settings from local storage
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _darkMode = prefs.getBool(_keyDarkMode) ?? true;
    _notificationsEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
    _soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
    _vibrationEnabled = prefs.getBool(_keyVibrationEnabled) ?? true;
    _locationEnabled = prefs.getBool(_keyLocationEnabled) ?? false;
    _language = prefs.getString(_keyLanguage) ?? 'en';
    
    // Load saved addresses
    final addressesJson = prefs.getString(_keySavedAddresses);
    if (addressesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(addressesJson);
        _savedAddresses = decoded.map((json) => SavedAddress.fromJson(json)).toList();
      } catch (e) {
        _savedAddresses = [];
      }
    }
    
    _isLoaded = true;
    notifyListeners();
  }
  
  /// Set dark mode
  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
    notifyListeners();
  }
  
  /// Set notifications enabled
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, value);
    notifyListeners();
  }
  
  /// Set sound enabled
  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundEnabled, value);
    notifyListeners();
  }
  
  /// Set vibration enabled
  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibrationEnabled, value);
    notifyListeners();
  }
  
  /// Set location enabled
  Future<void> setLocationEnabled(bool value) async {
    _locationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocationEnabled, value);
    notifyListeners();
  }
  
  /// Set language
  Future<void> setLanguage(String languageCode) async {
    _language = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, languageCode);
    notifyListeners();
  }
  
  // ============================================
  // SAVED ADDRESSES
  // ============================================
  
  /// Add a new address
  Future<void> addAddress(SavedAddress address) async {
    // If this is set as default, unset other defaults of same type
    if (address.isDefault) {
      for (var i = 0; i < _savedAddresses.length; i++) {
        if (_savedAddresses[i].type == address.type && _savedAddresses[i].isDefault) {
          _savedAddresses[i] = _savedAddresses[i].copyWith(isDefault: false);
        }
      }
    }
    
    _savedAddresses.add(address);
    await _saveAddresses();
    notifyListeners();
  }
  
  /// Update an existing address
  Future<void> updateAddress(String id, SavedAddress address) async {
    final index = _savedAddresses.indexWhere((a) => a.id == id);
    if (index != -1) {
      // If setting as default, unset other defaults of same type
      if (address.isDefault) {
        for (var i = 0; i < _savedAddresses.length; i++) {
          if (_savedAddresses[i].type == address.type && _savedAddresses[i].isDefault && i != index) {
            _savedAddresses[i] = _savedAddresses[i].copyWith(isDefault: false);
          }
        }
      }
      
      _savedAddresses[index] = address;
      await _saveAddresses();
      notifyListeners();
    }
  }
  
  /// Delete an address
  Future<void> deleteAddress(String id) async {
    _savedAddresses.removeWhere((a) => a.id == id);
    await _saveAddresses();
    notifyListeners();
  }
  
  /// Set address as default
  Future<void> setDefaultAddress(String id) async {
    final index = _savedAddresses.indexWhere((a) => a.id == id);
    if (index != -1) {
      final type = _savedAddresses[index].type;
      
      // Unset other defaults of same type
      for (var i = 0; i < _savedAddresses.length; i++) {
        if (_savedAddresses[i].type == type) {
          _savedAddresses[i] = _savedAddresses[i].copyWith(isDefault: i == index);
        }
      }
      
      await _saveAddresses();
      notifyListeners();
    }
  }
  
  /// Get default address of a type
  SavedAddress? getDefaultAddress(AddressType type) {
    try {
      return _savedAddresses.firstWhere((a) => a.type == type && a.isDefault);
    } catch (e) {
      // Return first of that type if no default
      try {
        return _savedAddresses.firstWhere((a) => a.type == type);
      } catch (e) {
        return null;
      }
    }
  }
  
  Future<void> _saveAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_savedAddresses.map((a) => a.toJson()).toList());
    await prefs.setString(_keySavedAddresses, json);
  }
  
  // ============================================
  // DATA EXPORT
  // ============================================
  
  /// Export all user data as JSON
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Fetch all user data from Supabase
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      final requests = await supabase
          .from('part_requests')
          .select('*, request_items(*)')
          .eq('mechanic_id', userId);
      
      final notifications = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId);
      
      final savedVehicles = await supabase
          .from('saved_vehicles')
          .select()
          .eq('user_id', userId);
      
      return {
        'export_date': DateTime.now().toIso8601String(),
        'user_id': userId,
        'profile': profile,
        'requests': requests,
        'notifications': notifications,
        'saved_vehicles': savedVehicles,
        'local_settings': {
          'dark_mode': _darkMode,
          'notifications_enabled': _notificationsEnabled,
          'sound_enabled': _soundEnabled,
          'vibration_enabled': _vibrationEnabled,
          'location_enabled': _locationEnabled,
          'language': _language,
        },
        'saved_addresses': _savedAddresses.map((a) => a.toJson()).toList(),
      };
    } catch (e) {
      throw Exception('Failed to export data: $e');
    }
  }
  
  // ============================================
  // ACCOUNT DELETION
  // ============================================
  
  /// Request account deletion
  /// This will:
  /// 1. Delete all user data from Supabase
  /// 2. Clear local storage
  /// 3. Sign out the user
  Future<void> deleteAccount(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Delete data in order (to respect foreign keys)
      // 1. Delete notifications
      await supabase.from('notifications').delete().eq('user_id', userId);
      
      // 2. Delete request items (via request_id)
      final requests = await supabase
          .from('part_requests')
          .select('id')
          .eq('mechanic_id', userId);
      
      for (final request in requests as List) {
        await supabase.from('request_items').delete().eq('request_id', request['id']);
        await supabase.from('request_chats').delete().eq('request_id', request['id']);
        await supabase.from('offers').delete().eq('request_id', request['id']);
      }
      
      // 3. Delete part requests
      await supabase.from('part_requests').delete().eq('mechanic_id', userId);
      
      // 4. Delete saved vehicles
      await supabase.from('saved_vehicles').delete().eq('user_id', userId);
      
      // 5. Delete chat messages where user is sender
      await supabase.from('messages').delete().eq('sender_id', userId);
      
      // 6. Delete profile
      await supabase.from('profiles').delete().eq('id', userId);
      
      // 7. Delete auth user (this will sign them out)
      // Note: This requires admin privileges or RLS policies that allow self-deletion
      // For now, we'll use the user deletion endpoint if available
      try {
        await supabase.auth.admin.deleteUser(userId);
      } catch (e) {
        // If admin deletion fails, try to delete via RPC or just sign out
        // The profile deletion above should be enough for most cases
      }
      
      // 8. Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // 9. Sign out
      await supabase.auth.signOut();
      
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
  
  /// Clear all local settings
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDarkMode);
    await prefs.remove(_keyNotificationsEnabled);
    await prefs.remove(_keySoundEnabled);
    await prefs.remove(_keyVibrationEnabled);
    await prefs.remove(_keyLocationEnabled);
    await prefs.remove(_keyLanguage);
    await prefs.remove(_keySavedAddresses);
    
    _darkMode = true;
    _notificationsEnabled = true;
    _soundEnabled = true;
    _vibrationEnabled = true;
    _locationEnabled = false;
    _language = 'en';
    _savedAddresses = [];
    
    notifyListeners();
  }
}

/// Provider for settings service
final settingsServiceProvider = ChangeNotifierProvider<SettingsService>((ref) {
  final service = SettingsService();
  service.loadSettings();
  return service;
});

// ============================================
// SAVED ADDRESS MODEL
// ============================================

enum AddressType { home, work, shop, delivery, other }

class SavedAddress {
  final String id;
  final String label;
  final AddressType type;
  final String streetAddress;
  final String? building;
  final String suburb;
  final String city;
  final String province;
  final String postalCode;
  final String country;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isDefault;
  final DateTime createdAt;

  SavedAddress({
    required this.id,
    required this.label,
    required this.type,
    required this.streetAddress,
    this.building,
    required this.suburb,
    required this.city,
    required this.province,
    required this.postalCode,
    this.country = 'South Africa',
    this.latitude,
    this.longitude,
    this.notes,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get fullAddress {
    final parts = <String>[];
    if (building != null && building!.isNotEmpty) parts.add(building!);
    parts.add(streetAddress);
    parts.add(suburb);
    parts.add(city);
    parts.add(province);
    parts.add(postalCode);
    return parts.join(', ');
  }

  String get shortAddress => '$streetAddress, $suburb';

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as String,
      label: json['label'] as String,
      type: AddressType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AddressType.other,
      ),
      streetAddress: json['street_address'] as String,
      building: json['building'] as String?,
      suburb: json['suburb'] as String,
      city: json['city'] as String,
      province: json['province'] as String,
      postalCode: json['postal_code'] as String,
      country: json['country'] as String? ?? 'South Africa',
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      notes: json['notes'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type.name,
      'street_address': streetAddress,
      'building': building,
      'suburb': suburb,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SavedAddress copyWith({
    String? id,
    String? label,
    AddressType? type,
    String? streetAddress,
    String? building,
    String? suburb,
    String? city,
    String? province,
    String? postalCode,
    String? country,
    double? latitude,
    double? longitude,
    String? notes,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      streetAddress: streetAddress ?? this.streetAddress,
      building: building ?? this.building,
      suburb: suburb ?? this.suburb,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ============================================
// SUPPORTED LANGUAGES
// ============================================

class SupportedLanguage {
  final String code;
  final String name;
  final String nativeName;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });
}

const List<SupportedLanguage> supportedLanguages = [
  SupportedLanguage(code: 'en', name: 'English', nativeName: 'English'),
  SupportedLanguage(code: 'af', name: 'Afrikaans', nativeName: 'Afrikaans'),
  SupportedLanguage(code: 'zu', name: 'Zulu', nativeName: 'isiZulu'),
  SupportedLanguage(code: 'xh', name: 'Xhosa', nativeName: 'isiXhosa'),
  SupportedLanguage(code: 'st', name: 'Sotho', nativeName: 'Sesotho'),
  SupportedLanguage(code: 'tn', name: 'Tswana', nativeName: 'Setswana'),
];
