import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline cache service for storing requests locally
/// Allows mechanics to view their list even without internet
class OfflineCacheService {
  static const String _keyRequestsCache = 'offline_requests_cache';
  static const String _keyCacheTimestamp = 'offline_cache_timestamp';
  static const String _keyNotificationsCache = 'offline_notifications_cache';
  
  // Cache expiry: 24 hours
  static const Duration cacheExpiry = Duration(hours: 24);
  
  // ============================================
  // REQUESTS CACHE
  // ============================================
  
  /// Save requests to local cache
  static Future<void> cacheRequests(List<Map<String, dynamic>> requests) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(requests);
    await prefs.setString(_keyRequestsCache, jsonString);
    await prefs.setString(_keyCacheTimestamp, DateTime.now().toIso8601String());
  }
  
  /// Get cached requests
  static Future<List<Map<String, dynamic>>?> getCachedRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyRequestsCache);
    
    if (jsonString == null) return null;
    
    // Check if cache is expired
    final timestampStr = prefs.getString(_keyCacheTimestamp);
    if (timestampStr != null) {
      final timestamp = DateTime.tryParse(timestampStr);
      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp);
        if (age > cacheExpiry) {
          // Cache expired, clear it
          await clearRequestsCache();
          return null;
        }
      }
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }
  
  /// Clear requests cache
  static Future<void> clearRequestsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRequestsCache);
    await prefs.remove(_keyCacheTimestamp);
  }
  
  /// Check if we have cached data
  static Future<bool> hasCachedRequests() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyRequestsCache);
  }
  
  /// Get cache age in human-readable format
  static Future<String?> getCacheAge() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_keyCacheTimestamp);
    
    if (timestampStr == null) return null;
    
    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) return null;
    
    final age = DateTime.now().difference(timestamp);
    
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
  
  // ============================================
  // NOTIFICATIONS CACHE
  // ============================================
  
  /// Save notifications to local cache
  static Future<void> cacheNotifications(List<Map<String, dynamic>> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(notifications);
    await prefs.setString(_keyNotificationsCache, jsonString);
  }
  
  /// Get cached notifications
  static Future<List<Map<String, dynamic>>?> getCachedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyNotificationsCache);
    
    if (jsonString == null) return null;
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }
  
  /// Clear all caches
  static Future<void> clearAllCaches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRequestsCache);
    await prefs.remove(_keyCacheTimestamp);
    await prefs.remove(_keyNotificationsCache);
  }
}

