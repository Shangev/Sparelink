import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification sound options
enum NotificationSound {
  defaultSound,
  chime,
  bell,
  alert,
  gentle,
  urgent,
  silent,
}

extension NotificationSoundExtension on NotificationSound {
  String get displayName {
    switch (this) {
      case NotificationSound.defaultSound:
        return 'Default';
      case NotificationSound.chime:
        return 'Chime';
      case NotificationSound.bell:
        return 'Bell';
      case NotificationSound.alert:
        return 'Alert';
      case NotificationSound.gentle:
        return 'Gentle';
      case NotificationSound.urgent:
        return 'Urgent';
      case NotificationSound.silent:
        return 'Silent';
    }
  }

  String get description {
    switch (this) {
      case NotificationSound.defaultSound:
        return 'Standard notification tone';
      case NotificationSound.chime:
        return 'Soft melodic chime';
      case NotificationSound.bell:
        return 'Classic bell sound';
      case NotificationSound.alert:
        return 'Attention-grabbing alert';
      case NotificationSound.gentle:
        return 'Quiet, non-intrusive';
      case NotificationSound.urgent:
        return 'High priority alert';
      case NotificationSound.silent:
        return 'No sound, vibration only';
    }
  }
}

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
  
  // Notification Preferences Keys
  static const String _keyNewQuotesNotifications = 'settings_new_quotes_notifications';
  static const String _keyOrderUpdatesNotifications = 'settings_order_updates_notifications';
  static const String _keyChatMessagesNotifications = 'settings_chat_messages_notifications';
  
  // Sound Customization Keys
  static const String _keyNotificationSound = 'settings_notification_sound';
  static const String _keyQuotesSound = 'settings_quotes_sound';
  static const String _keyOrdersSound = 'settings_orders_sound';
  static const String _keyChatSound = 'settings_chat_sound';
  
  // Quiet Hours Keys
  static const String _keyQuietHoursEnabled = 'settings_quiet_hours_enabled';
  static const String _keyQuietHoursStart = 'settings_quiet_hours_start';
  static const String _keyQuietHoursEnd = 'settings_quiet_hours_end';
  static const String _keyQuietHoursWeekends = 'settings_quiet_hours_weekends';
  static const String _keyQuietHoursWeekdaysOnly = 'settings_quiet_hours_weekdays_only';
  
  // Default values
  bool _darkMode = true;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _locationEnabled = false;
  String _language = 'en';
  List<SavedAddress> _savedAddresses = [];
  bool _isLoaded = false;
  
  // Notification Preferences
  bool _newQuotesNotifications = true;
  bool _orderUpdatesNotifications = true;
  bool _chatMessagesNotifications = true;
  
  // Sound Customization
  NotificationSound _notificationSound = NotificationSound.defaultSound;
  NotificationSound _quotesSound = NotificationSound.defaultSound;
  NotificationSound _ordersSound = NotificationSound.defaultSound;
  NotificationSound _chatSound = NotificationSound.chime;
  
  // Quiet Hours
  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 20, minute: 0); // 8 PM
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);   // 7 AM
  bool _quietHoursWeekends = false; // Apply quiet hours on weekends
  bool _quietHoursWeekdaysOnly = false; // Only apply on weekdays
  
  // Getters - General
  bool get darkMode => _darkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get locationEnabled => _locationEnabled;
  String get language => _language;
  List<SavedAddress> get savedAddresses => List.unmodifiable(_savedAddresses);
  bool get isLoaded => _isLoaded;
  
  // Getters - Notification Preferences
  bool get newQuotesNotifications => _newQuotesNotifications;
  bool get orderUpdatesNotifications => _orderUpdatesNotifications;
  bool get chatMessagesNotifications => _chatMessagesNotifications;
  
  // Getters - Sound Customization
  NotificationSound get notificationSound => _notificationSound;
  NotificationSound get quotesSound => _quotesSound;
  NotificationSound get ordersSound => _ordersSound;
  NotificationSound get chatSound => _chatSound;
  
  // Getters - Quiet Hours
  bool get quietHoursEnabled => _quietHoursEnabled;
  TimeOfDay get quietHoursStart => _quietHoursStart;
  TimeOfDay get quietHoursEnd => _quietHoursEnd;
  bool get quietHoursWeekends => _quietHoursWeekends;
  bool get quietHoursWeekdaysOnly => _quietHoursWeekdaysOnly;
  
  /// Load settings from local storage
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // General settings
    _darkMode = prefs.getBool(_keyDarkMode) ?? true;
    _notificationsEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
    _soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
    _vibrationEnabled = prefs.getBool(_keyVibrationEnabled) ?? true;
    _locationEnabled = prefs.getBool(_keyLocationEnabled) ?? false;
    _language = prefs.getString(_keyLanguage) ?? 'en';
    
    // Notification Preferences
    _newQuotesNotifications = prefs.getBool(_keyNewQuotesNotifications) ?? true;
    _orderUpdatesNotifications = prefs.getBool(_keyOrderUpdatesNotifications) ?? true;
    _chatMessagesNotifications = prefs.getBool(_keyChatMessagesNotifications) ?? true;
    
    // Sound Customization
    final soundIndex = prefs.getInt(_keyNotificationSound) ?? 0;
    _notificationSound = NotificationSound.values[soundIndex.clamp(0, NotificationSound.values.length - 1)];
    final quotesSoundIndex = prefs.getInt(_keyQuotesSound) ?? 0;
    _quotesSound = NotificationSound.values[quotesSoundIndex.clamp(0, NotificationSound.values.length - 1)];
    final ordersSoundIndex = prefs.getInt(_keyOrdersSound) ?? 0;
    _ordersSound = NotificationSound.values[ordersSoundIndex.clamp(0, NotificationSound.values.length - 1)];
    final chatSoundIndex = prefs.getInt(_keyChatSound) ?? 1; // Default to chime
    _chatSound = NotificationSound.values[chatSoundIndex.clamp(0, NotificationSound.values.length - 1)];
    
    // Quiet Hours
    _quietHoursEnabled = prefs.getBool(_keyQuietHoursEnabled) ?? false;
    final startMinutes = prefs.getInt(_keyQuietHoursStart) ?? (20 * 60); // 8 PM default
    _quietHoursStart = TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);
    final endMinutes = prefs.getInt(_keyQuietHoursEnd) ?? (7 * 60); // 7 AM default
    _quietHoursEnd = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
    _quietHoursWeekends = prefs.getBool(_keyQuietHoursWeekends) ?? false;
    _quietHoursWeekdaysOnly = prefs.getBool(_keyQuietHoursWeekdaysOnly) ?? false;
    
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
  // NOTIFICATION PREFERENCES
  // ============================================
  
  /// Set new quotes notifications
  Future<void> setNewQuotesNotifications(bool value) async {
    _newQuotesNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNewQuotesNotifications, value);
    notifyListeners();
  }
  
  /// Set order updates notifications
  Future<void> setOrderUpdatesNotifications(bool value) async {
    _orderUpdatesNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOrderUpdatesNotifications, value);
    notifyListeners();
  }
  
  /// Set chat messages notifications
  Future<void> setChatMessagesNotifications(bool value) async {
    _chatMessagesNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyChatMessagesNotifications, value);
    notifyListeners();
  }
  
  // ============================================
  // SOUND CUSTOMIZATION
  // ============================================
  
  /// Set default notification sound
  Future<void> setNotificationSound(NotificationSound sound) async {
    _notificationSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNotificationSound, sound.index);
    notifyListeners();
  }
  
  /// Set quotes notification sound
  Future<void> setQuotesSound(NotificationSound sound) async {
    _quotesSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyQuotesSound, sound.index);
    notifyListeners();
  }
  
  /// Set orders notification sound
  Future<void> setOrdersSound(NotificationSound sound) async {
    _ordersSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOrdersSound, sound.index);
    notifyListeners();
  }
  
  /// Set chat notification sound
  Future<void> setChatSound(NotificationSound sound) async {
    _chatSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyChatSound, sound.index);
    notifyListeners();
  }
  
  /// Get sound for a specific notification type
  NotificationSound getSoundForType(String notificationType) {
    switch (notificationType) {
      case 'quote':
      case 'new_quote':
        return _quotesSound;
      case 'order':
      case 'order_update':
        return _ordersSound;
      case 'chat':
      case 'message':
        return _chatSound;
      default:
        return _notificationSound;
    }
  }
  
  // ============================================
  // QUIET HOURS
  // ============================================
  
  /// Set quiet hours enabled
  Future<void> setQuietHoursEnabled(bool value) async {
    _quietHoursEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyQuietHoursEnabled, value);
    notifyListeners();
  }
  
  /// Set quiet hours start time
  Future<void> setQuietHoursStart(TimeOfDay time) async {
    _quietHoursStart = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyQuietHoursStart, time.hour * 60 + time.minute);
    notifyListeners();
  }
  
  /// Set quiet hours end time
  Future<void> setQuietHoursEnd(TimeOfDay time) async {
    _quietHoursEnd = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyQuietHoursEnd, time.hour * 60 + time.minute);
    notifyListeners();
  }
  
  /// Set whether quiet hours apply on weekends
  Future<void> setQuietHoursWeekends(bool value) async {
    _quietHoursWeekends = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyQuietHoursWeekends, value);
    notifyListeners();
  }
  
  /// Set whether quiet hours apply only on weekdays
  Future<void> setQuietHoursWeekdaysOnly(bool value) async {
    _quietHoursWeekdaysOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyQuietHoursWeekdaysOnly, value);
    notifyListeners();
  }
  
  /// Check if current time is within quiet hours
  bool isInQuietHours() {
    if (!_quietHoursEnabled) return false;
    
    final now = DateTime.now();
    final currentDay = now.weekday; // 1 = Monday, 7 = Sunday
    final isWeekend = currentDay == 6 || currentDay == 7; // Saturday or Sunday
    
    // Check day-of-week restrictions
    if (_quietHoursWeekdaysOnly && isWeekend) {
      return false; // Quiet hours only on weekdays, but it's weekend
    }
    if (!_quietHoursWeekends && isWeekend) {
      return false; // Quiet hours disabled on weekends
    }
    
    // Convert times to minutes since midnight for easier comparison
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _quietHoursStart.hour * 60 + _quietHoursStart.minute;
    final endMinutes = _quietHoursEnd.hour * 60 + _quietHoursEnd.minute;
    
    // Handle overnight quiet hours (e.g., 8 PM to 7 AM)
    if (startMinutes > endMinutes) {
      // Quiet hours span midnight
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      // Quiet hours within same day
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }
  
  /// Check if notifications should be delivered for a given type
  bool shouldDeliverNotification(String notificationType) {
    // First check if we're in quiet hours
    if (isInQuietHours()) return false;
    
    // Check if notifications are globally enabled
    if (!_notificationsEnabled) return false;
    
    // Check type-specific settings
    switch (notificationType) {
      case 'quote':
      case 'new_quote':
        return _newQuotesNotifications;
      case 'order':
      case 'order_update':
        return _orderUpdatesNotifications;
      case 'chat':
      case 'message':
        return _chatMessagesNotifications;
      default:
        return true;
    }
  }
  
  /// Get formatted quiet hours string
  String get quietHoursDescription {
    if (!_quietHoursEnabled) return 'Disabled';
    
    String formatTime(TimeOfDay t) {
      final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      final minute = t.minute.toString().padLeft(2, '0');
      final period = t.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }
    
    String days = '';
    if (_quietHoursWeekdaysOnly) {
      days = ' (weekdays only)';
    } else if (_quietHoursWeekends) {
      days = ' (including weekends)';
    } else {
      days = ' (weekdays)';
    }
    
    return '${formatTime(_quietHoursStart)} - ${formatTime(_quietHoursEnd)}$days';
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
          'notification_preferences': {
            'new_quotes': _newQuotesNotifications,
            'order_updates': _orderUpdatesNotifications,
            'chat_messages': _chatMessagesNotifications,
          },
          'notification_sounds': {
            'default': _notificationSound.name,
            'quotes': _quotesSound.name,
            'orders': _ordersSound.name,
            'chat': _chatSound.name,
          },
          'quiet_hours': {
            'enabled': _quietHoursEnabled,
            'start': '${_quietHoursStart.hour}:${_quietHoursStart.minute}',
            'end': '${_quietHoursEnd.hour}:${_quietHoursEnd.minute}',
            'weekends': _quietHoursWeekends,
            'weekdays_only': _quietHoursWeekdaysOnly,
          },
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
    
    // Clear general settings
    await prefs.remove(_keyDarkMode);
    await prefs.remove(_keyNotificationsEnabled);
    await prefs.remove(_keySoundEnabled);
    await prefs.remove(_keyVibrationEnabled);
    await prefs.remove(_keyLocationEnabled);
    await prefs.remove(_keyLanguage);
    await prefs.remove(_keySavedAddresses);
    
    // Clear notification preferences
    await prefs.remove(_keyNewQuotesNotifications);
    await prefs.remove(_keyOrderUpdatesNotifications);
    await prefs.remove(_keyChatMessagesNotifications);
    
    // Clear sound customization
    await prefs.remove(_keyNotificationSound);
    await prefs.remove(_keyQuotesSound);
    await prefs.remove(_keyOrdersSound);
    await prefs.remove(_keyChatSound);
    
    // Clear quiet hours
    await prefs.remove(_keyQuietHoursEnabled);
    await prefs.remove(_keyQuietHoursStart);
    await prefs.remove(_keyQuietHoursEnd);
    await prefs.remove(_keyQuietHoursWeekends);
    await prefs.remove(_keyQuietHoursWeekdaysOnly);
    
    // Reset general settings to defaults
    _darkMode = true;
    _notificationsEnabled = true;
    _soundEnabled = true;
    _vibrationEnabled = true;
    _locationEnabled = false;
    _language = 'en';
    _savedAddresses = [];
    
    // Reset notification preferences to defaults
    _newQuotesNotifications = true;
    _orderUpdatesNotifications = true;
    _chatMessagesNotifications = true;
    
    // Reset sound customization to defaults
    _notificationSound = NotificationSound.defaultSound;
    _quotesSound = NotificationSound.defaultSound;
    _ordersSound = NotificationSound.defaultSound;
    _chatSound = NotificationSound.chime;
    
    // Reset quiet hours to defaults
    _quietHoursEnabled = false;
    _quietHoursStart = const TimeOfDay(hour: 20, minute: 0);
    _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);
    _quietHoursWeekends = false;
    _quietHoursWeekdaysOnly = false;
    
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
