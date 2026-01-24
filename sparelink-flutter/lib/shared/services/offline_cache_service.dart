import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline cache service for storing data locally
/// Allows users to view their data even without internet
/// 
/// Extended in Pass 2 Phase 4 to include orders and offers
class OfflineCacheService {
  // Cache keys
  static const String _keyRequestsCache = 'offline_requests_cache';
  static const String _keyCacheTimestamp = 'offline_cache_timestamp';
  static const String _keyNotificationsCache = 'offline_notifications_cache';
  static const String _keyOrdersCache = 'offline_orders_cache';
  static const String _keyOrdersTimestamp = 'offline_orders_timestamp';
  static const String _keyOffersCache = 'offline_offers_cache';
  static const String _keyOffersTimestamp = 'offline_offers_timestamp';
  static const String _keyProfileCache = 'offline_profile_cache';
  static const String _keyVehiclesCache = 'offline_vehicles_cache';
  
  // Cache expiry durations
  static const Duration cacheExpiry = Duration(hours: 24);
  static const Duration ordersCacheExpiry = Duration(hours: 12); // Orders update more frequently
  static const Duration offersCacheExpiry = Duration(hours: 6);  // Offers can expire quickly
  
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
    await prefs.remove(_keyOrdersCache);
    await prefs.remove(_keyOrdersTimestamp);
    await prefs.remove(_keyOffersCache);
    await prefs.remove(_keyOffersTimestamp);
    await prefs.remove(_keyProfileCache);
    await prefs.remove(_keyVehiclesCache);
    debugPrint('🗑️ All offline caches cleared');
  }
  
  // ============================================
  // ORDERS CACHE (Pass 2 Phase 4)
  // ============================================
  
  /// Save orders to local cache
  static Future<void> cacheOrders(List<Map<String, dynamic>> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(orders);
    await prefs.setString(_keyOrdersCache, jsonString);
    await prefs.setString(_keyOrdersTimestamp, DateTime.now().toIso8601String());
    debugPrint('💾 Cached ${orders.length} orders');
  }
  
  /// Get cached orders
  static Future<List<Map<String, dynamic>>?> getCachedOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyOrdersCache);
    
    if (jsonString == null) return null;
    
    // Check if cache is expired
    final timestampStr = prefs.getString(_keyOrdersTimestamp);
    if (timestampStr != null) {
      final timestamp = DateTime.tryParse(timestampStr);
      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp);
        if (age > ordersCacheExpiry) {
          await clearOrdersCache();
          return null;
        }
      }
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      debugPrint('📦 Retrieved ${decoded.length} orders from cache');
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('⚠️ Error decoding orders cache: $e');
      return null;
    }
  }
  
  /// Clear orders cache
  static Future<void> clearOrdersCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOrdersCache);
    await prefs.remove(_keyOrdersTimestamp);
  }
  
  /// Check if we have cached orders
  static Future<bool> hasCachedOrders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyOrdersCache);
  }
  
  /// Get orders cache age
  static Future<String?> getOrdersCacheAge() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_keyOrdersTimestamp);
    return _formatAge(timestampStr);
  }
  
  // ============================================
  // OFFERS CACHE (Pass 2 Phase 4)
  // ============================================
  
  /// Save offers for a request to local cache
  static Future<void> cacheOffers(String requestId, List<Map<String, dynamic>> offers) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing offers cache (keyed by request ID)
    Map<String, dynamic> allOffers = {};
    final existingCache = prefs.getString(_keyOffersCache);
    if (existingCache != null) {
      try {
        allOffers = Map<String, dynamic>.from(jsonDecode(existingCache));
      } catch (_) {}
    }
    
    // Update offers for this request
    allOffers[requestId] = {
      'offers': offers,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString(_keyOffersCache, jsonEncode(allOffers));
    debugPrint('💾 Cached ${offers.length} offers for request $requestId');
  }
  
  /// Get cached offers for a request
  static Future<List<Map<String, dynamic>>?> getCachedOffers(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyOffersCache);
    
    if (jsonString == null) return null;
    
    try {
      final allOffers = Map<String, dynamic>.from(jsonDecode(jsonString));
      final requestOffers = allOffers[requestId];
      
      if (requestOffers == null) return null;
      
      // Check if cache is expired
      final timestampStr = requestOffers['timestamp'] as String?;
      if (timestampStr != null) {
        final timestamp = DateTime.tryParse(timestampStr);
        if (timestamp != null) {
          final age = DateTime.now().difference(timestamp);
          if (age > offersCacheExpiry) {
            // Remove expired offers for this request
            allOffers.remove(requestId);
            await prefs.setString(_keyOffersCache, jsonEncode(allOffers));
            return null;
          }
        }
      }
      
      final offers = (requestOffers['offers'] as List<dynamic>);
      debugPrint('📦 Retrieved ${offers.length} offers from cache for request $requestId');
      return offers.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('⚠️ Error decoding offers cache: $e');
      return null;
    }
  }
  
  /// Clear offers cache for a specific request
  static Future<void> clearOffersCache(String? requestId) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (requestId == null) {
      // Clear all offers
      await prefs.remove(_keyOffersCache);
      await prefs.remove(_keyOffersTimestamp);
      return;
    }
    
    // Clear only for specific request
    final jsonString = prefs.getString(_keyOffersCache);
    if (jsonString != null) {
      try {
        final allOffers = Map<String, dynamic>.from(jsonDecode(jsonString));
        allOffers.remove(requestId);
        await prefs.setString(_keyOffersCache, jsonEncode(allOffers));
      } catch (_) {}
    }
  }
  
  // ============================================
  // PROFILE CACHE (Pass 2 Phase 4)
  // ============================================
  
  /// Save profile to local cache
  static Future<void> cacheProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfileCache, jsonEncode(profile));
    debugPrint('💾 Cached user profile');
  }
  
  /// Get cached profile
  static Future<Map<String, dynamic>?> getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyProfileCache);
    
    if (jsonString == null) return null;
    
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (e) {
      return null;
    }
  }
  
  /// Clear profile cache
  static Future<void> clearProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfileCache);
  }
  
  // ============================================
  // VEHICLES CACHE (Pass 2 Phase 4)
  // ============================================
  
  /// Save vehicles to local cache
  static Future<void> cacheVehicles(List<Map<String, dynamic>> vehicles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVehiclesCache, jsonEncode(vehicles));
    debugPrint('💾 Cached ${vehicles.length} vehicles');
  }
  
  /// Get cached vehicles
  static Future<List<Map<String, dynamic>>?> getCachedVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyVehiclesCache);
    
    if (jsonString == null) return null;
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return null;
    }
  }
  
  /// Clear vehicles cache
  static Future<void> clearVehiclesCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVehiclesCache);
  }
  
  // ============================================
  // UTILITY METHODS
  // ============================================
  
  /// Format cache age to human-readable string
  static String? _formatAge(String? timestampStr) {
    if (timestampStr == null) return null;
    
    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) return null;
    
    final age = DateTime.now().difference(timestamp);
    
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
  
  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    int totalSize = 0;
    int itemCount = 0;
    
    for (final key in [
      _keyRequestsCache,
      _keyOrdersCache,
      _keyOffersCache,
      _keyNotificationsCache,
      _keyProfileCache,
      _keyVehiclesCache,
    ]) {
      final value = prefs.getString(key);
      if (value != null) {
        totalSize += value.length;
        itemCount++;
      }
    }
    
    return {
      'totalSizeBytes': totalSize,
      'totalSizeKB': (totalSize / 1024).toStringAsFixed(2),
      'itemCount': itemCount,
      'requestsAge': await getCacheAge(),
      'ordersAge': await getOrdersCacheAge(),
    };
  }
  
  /// Check if app is in offline mode (has cached data but may not have network)
  static Future<bool> hasOfflineData() async {
    return await hasCachedRequests() || 
           await hasCachedOrders();
  }
  
  // ============================================
  // PENDING SYNC QUEUE (Pass 3 Final Polish)
  // ============================================
  // When offline, queue critical actions (like accepting quotes) 
  // and sync when connection is restored
  
  static const String _keyPendingSyncQueue = 'pending_sync_queue';
  
  /// Add an action to the pending sync queue (for offline use)
  static Future<void> queuePendingAction(PendingAction action) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing queue
    List<Map<String, dynamic>> queue = [];
    final existingJson = prefs.getString(_keyPendingSyncQueue);
    if (existingJson != null) {
      try {
        queue = List<Map<String, dynamic>>.from(
          (jsonDecode(existingJson) as List).map((e) => Map<String, dynamic>.from(e))
        );
      } catch (_) {}
    }
    
    // Add new action
    queue.add(action.toJson());
    await prefs.setString(_keyPendingSyncQueue, jsonEncode(queue));
    debugPrint('📥 Queued pending action: ${action.type.name} for ${action.resourceId}');
  }
  
  /// Get all pending actions
  static Future<List<PendingAction>> getPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyPendingSyncQueue);
    
    if (jsonString == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((e) => PendingAction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Error decoding pending actions: $e');
      return [];
    }
  }
  
  /// Check if there are pending actions to sync
  static Future<bool> hasPendingActions() async {
    final actions = await getPendingActions();
    return actions.isNotEmpty;
  }
  
  /// Get count of pending actions
  static Future<int> getPendingActionCount() async {
    final actions = await getPendingActions();
    return actions.length;
  }
  
  /// Remove a pending action after successful sync
  static Future<void> removePendingAction(String actionId) async {
    final prefs = await SharedPreferences.getInstance();
    final actions = await getPendingActions();
    
    final filtered = actions.where((a) => a.id != actionId).toList();
    await prefs.setString(
      _keyPendingSyncQueue, 
      jsonEncode(filtered.map((a) => a.toJson()).toList()),
    );
    debugPrint('✅ Removed synced action: $actionId');
  }
  
  /// Clear all pending actions (use with caution)
  static Future<void> clearPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingSyncQueue);
    debugPrint('🗑️ Cleared all pending actions');
  }
  
  /// Mark an action as failed with error message
  static Future<void> markActionFailed(String actionId, String error) async {
    final prefs = await SharedPreferences.getInstance();
    final actions = await getPendingActions();
    
    final updated = actions.map((a) {
      if (a.id == actionId) {
        return PendingAction(
          id: a.id,
          type: a.type,
          resourceId: a.resourceId,
          payload: a.payload,
          createdAt: a.createdAt,
          retryCount: a.retryCount + 1,
          lastError: error,
          status: a.retryCount >= 2 ? PendingSyncStatus.failed : PendingSyncStatus.pending,
        );
      }
      return a;
    }).toList();
    
    await prefs.setString(
      _keyPendingSyncQueue, 
      jsonEncode(updated.map((a) => a.toJson()).toList()),
    );
  }
}

/// Types of actions that can be queued for offline sync
enum PendingActionType {
  acceptOffer,      // Mechanic accepts a quote while offline
  rejectOffer,      // Mechanic rejects a quote
  cancelOrder,      // Mechanic cancels an order
  sendMessage,      // Send a chat message
  updateProfile,    // Profile update
}

/// Status of a pending sync action
enum PendingSyncStatus {
  pending,    // Waiting to sync
  syncing,    // Currently syncing
  failed,     // Failed after max retries
  completed,  // Successfully synced (should be removed)
}

/// Represents an action queued for sync when offline
class PendingAction {
  final String id;
  final PendingActionType type;
  final String resourceId;  // offer_id, order_id, message_id, etc.
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final PendingSyncStatus status;
  
  PendingAction({
    required this.id,
    required this.type,
    required this.resourceId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.status = PendingSyncStatus.pending,
  });
  
  /// Create a new pending action with auto-generated ID
  factory PendingAction.create({
    required PendingActionType type,
    required String resourceId,
    Map<String, dynamic>? payload,
  }) {
    return PendingAction(
      id: '${type.name}_${resourceId}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      resourceId: resourceId,
      payload: payload ?? {},
      createdAt: DateTime.now(),
    );
  }
  
  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'] ?? '',
      type: PendingActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PendingActionType.acceptOffer,
      ),
      resourceId: json['resource_id'] ?? '',
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      retryCount: json['retry_count'] ?? 0,
      lastError: json['last_error'],
      status: PendingSyncStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PendingSyncStatus.pending,
      ),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'resource_id': resourceId,
    'payload': payload,
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
    'last_error': lastError,
    'status': status.name,
  };
  
  /// Human-readable description for UI
  String get displayDescription {
    switch (type) {
      case PendingActionType.acceptOffer:
        return 'Accept quote';
      case PendingActionType.rejectOffer:
        return 'Reject quote';
      case PendingActionType.cancelOrder:
        return 'Cancel order';
      case PendingActionType.sendMessage:
        return 'Send message';
      case PendingActionType.updateProfile:
        return 'Update profile';
    }
  }
  
  /// Time since creation
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

