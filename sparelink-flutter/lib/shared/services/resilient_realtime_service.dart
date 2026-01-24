import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// RESILIENT REALTIME SERVICE
// Pass 2 Phase 4 Implementation
// Provides WebSocket subscriptions with automatic reconnection
// =============================================================================

/// Configuration for reconnection behavior
class ReconnectConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool addJitter;
  
  const ReconnectConfig({
    this.maxAttempts = 10,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 60),
    this.backoffMultiplier = 2.0,
    this.addJitter = true,
  });
  
  static const defaultConfig = ReconnectConfig();
}

/// Connection state for realtime subscriptions
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Callback types for realtime events
typedef OnDataCallback = void Function(Map<String, dynamic> data);
typedef OnStateChangeCallback = void Function(ConnectionState state);
typedef OnErrorCallback = void Function(dynamic error);

/// A resilient realtime channel that automatically reconnects on disconnection
class ResilientRealtimeChannel {
  final SupabaseClient _client;
  final String channelName;
  final String table;
  final String? filterColumn;
  final String? filterValue;
  final PostgresChangeEvent event;
  final ReconnectConfig config;
  
  RealtimeChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  ConnectionState _state = ConnectionState.disconnected;
  bool _disposed = false;
  
  OnDataCallback? _onData;
  OnStateChangeCallback? _onStateChange;
  OnErrorCallback? _onError;
  
  static final Random _random = Random();
  
  ResilientRealtimeChannel({
    required SupabaseClient client,
    required this.channelName,
    required this.table,
    this.filterColumn,
    this.filterValue,
    this.event = PostgresChangeEvent.all,
    this.config = const ReconnectConfig(),
  }) : _client = client;
  
  /// Current connection state
  ConnectionState get state => _state;
  
  /// Whether the channel is connected
  bool get isConnected => _state == ConnectionState.connected;
  
  /// Subscribe to the channel with callbacks
  void subscribe({
    required OnDataCallback onData,
    OnStateChangeCallback? onStateChange,
    OnErrorCallback? onError,
  }) {
    _onData = onData;
    _onStateChange = onStateChange;
    _onError = onError;
    _connect();
  }
  
  /// Manually reconnect
  void reconnect() {
    _cleanup();
    _reconnectAttempts = 0;
    _connect();
  }
  
  /// Dispose the channel and stop reconnection attempts
  void dispose() {
    _disposed = true;
    _cleanup();
    debugPrint('🔌 [$channelName] Channel disposed');
  }
  
  void _connect() {
    if (_disposed) return;
    
    _setState(ConnectionState.connecting);
    debugPrint('🔌 [$channelName] Connecting...');
    
    try {
      // Build the channel with postgres changes
      _channel = _client.channel(channelName);
      
      // Add postgres changes listener
      if (filterColumn != null && filterValue != null) {
        _channel!.onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: filterColumn!,
            value: filterValue!,
          ),
          callback: _handlePayload,
        );
      } else {
        _channel!.onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          callback: _handlePayload,
        );
      }
      
      // Subscribe and handle status changes
      _channel!.subscribe((status, error) {
        if (_disposed) return;
        
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            _reconnectAttempts = 0;
            _setState(ConnectionState.connected);
            debugPrint('✅ [$channelName] Connected');
            break;
            
          case RealtimeSubscribeStatus.closed:
            debugPrint('⚠️ [$channelName] Connection closed');
            _handleDisconnect();
            break;
            
          case RealtimeSubscribeStatus.channelError:
            debugPrint('❌ [$channelName] Channel error: $error');
            _onError?.call(error);
            _handleDisconnect();
            break;
            
          case RealtimeSubscribeStatus.timedOut:
            debugPrint('⏱️ [$channelName] Connection timed out');
            _handleDisconnect();
            break;
        }
      });
    } catch (e) {
      debugPrint('❌ [$channelName] Failed to connect: $e');
      _onError?.call(e);
      _handleDisconnect();
    }
  }
  
  void _handlePayload(PostgresChangePayload payload) {
    if (_disposed) return;
    
    try {
      Map<String, dynamic> data;
      
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          data = payload.newRecord;
          break;
        case PostgresChangeEvent.delete:
          data = payload.oldRecord;
          break;
        default:
          data = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      }
      
      debugPrint('📨 [$channelName] Received ${payload.eventType.name} event');
      _onData?.call(data);
    } catch (e) {
      debugPrint('❌ [$channelName] Error handling payload: $e');
      _onError?.call(e);
    }
  }
  
  void _handleDisconnect() {
    if (_disposed) return;
    
    _cleanup();
    
    if (_reconnectAttempts >= config.maxAttempts) {
      _setState(ConnectionState.failed);
      debugPrint('❌ [$channelName] Max reconnect attempts reached');
      _onError?.call(Exception('Max reconnect attempts reached'));
      return;
    }
    
    _scheduleReconnect();
  }
  
  void _scheduleReconnect() {
    if (_disposed) return;
    
    _setState(ConnectionState.reconnecting);
    
    // Calculate delay with exponential backoff
    var delay = Duration(
      milliseconds: (config.initialDelay.inMilliseconds * 
                    pow(config.backoffMultiplier, _reconnectAttempts)).round(),
    );
    
    // Cap at max delay
    if (delay > config.maxDelay) {
      delay = config.maxDelay;
    }
    
    // Add jitter (±25%)
    if (config.addJitter) {
      final jitterFactor = 0.75 + (_random.nextDouble() * 0.5);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * jitterFactor).round(),
      );
    }
    
    _reconnectAttempts++;
    
    debugPrint('🔄 [$channelName] Reconnecting in ${delay.inSeconds}s '
        '(attempt $_reconnectAttempts/${config.maxAttempts})');
    
    _reconnectTimer = Timer(delay, () {
      if (!_disposed) {
        _connect();
      }
    });
  }
  
  void _cleanup() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    if (_channel != null) {
      try {
        _channel!.unsubscribe();
      } catch (e) {
        debugPrint('⚠️ [$channelName] Error unsubscribing: $e');
      }
      _channel = null;
    }
  }
  
  void _setState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _onStateChange?.call(newState);
    }
  }
}

/// Service to manage multiple resilient realtime channels
class ResilientRealtimeService {
  final SupabaseClient _client;
  final Map<String, ResilientRealtimeChannel> _channels = {};
  
  ResilientRealtimeService(this._client);
  
  /// Subscribe to order updates
  ResilientRealtimeChannel subscribeToOrder({
    required String orderId,
    required OnDataCallback onUpdate,
    OnStateChangeCallback? onStateChange,
    OnErrorCallback? onError,
  }) {
    final channelName = 'order_$orderId';
    
    final channel = ResilientRealtimeChannel(
      client: _client,
      channelName: channelName,
      table: 'orders',
      filterColumn: 'id',
      filterValue: orderId,
      event: PostgresChangeEvent.update,
    );
    
    channel.subscribe(
      onData: onUpdate,
      onStateChange: onStateChange,
      onError: onError,
    );
    
    _channels[channelName] = channel;
    return channel;
  }
  
  /// Subscribe to new offers for a request
  ResilientRealtimeChannel subscribeToOffersForRequest({
    required String requestId,
    required OnDataCallback onNewOffer,
    OnStateChangeCallback? onStateChange,
    OnErrorCallback? onError,
  }) {
    final channelName = 'offers_$requestId';
    
    final channel = ResilientRealtimeChannel(
      client: _client,
      channelName: channelName,
      table: 'offers',
      filterColumn: 'request_id',
      filterValue: requestId,
      event: PostgresChangeEvent.insert,
    );
    
    channel.subscribe(
      onData: onNewOffer,
      onStateChange: onStateChange,
      onError: onError,
    );
    
    _channels[channelName] = channel;
    return channel;
  }
  
  /// Subscribe to messages in a conversation
  ResilientRealtimeChannel subscribeToMessages({
    required String conversationId,
    required OnDataCallback onNewMessage,
    OnStateChangeCallback? onStateChange,
    OnErrorCallback? onError,
  }) {
    final channelName = 'messages_$conversationId';
    
    final channel = ResilientRealtimeChannel(
      client: _client,
      channelName: channelName,
      table: 'messages',
      filterColumn: 'conversation_id',
      filterValue: conversationId,
      event: PostgresChangeEvent.insert,
    );
    
    channel.subscribe(
      onData: onNewMessage,
      onStateChange: onStateChange,
      onError: onError,
    );
    
    _channels[channelName] = channel;
    return channel;
  }
  
  /// Subscribe to request chat messages
  ResilientRealtimeChannel subscribeToRequestChatMessages({
    required String requestId,
    required String shopId,
    required OnDataCallback onNewMessage,
    OnStateChangeCallback? onStateChange,
    OnErrorCallback? onError,
  }) {
    final channelName = 'chat_${requestId}_$shopId';
    
    // For request_chat_messages, we need a custom setup
    final channel = ResilientRealtimeChannel(
      client: _client,
      channelName: channelName,
      table: 'request_chat_messages',
      filterColumn: 'request_id',
      filterValue: requestId,
      event: PostgresChangeEvent.insert,
    );
    
    channel.subscribe(
      onData: (data) {
        // Filter by shop_id client-side
        if (data['shop_id'] == shopId) {
          onNewMessage(data);
        }
      },
      onStateChange: onStateChange,
      onError: onError,
    );
    
    _channels[channelName] = channel;
    return channel;
  }
  
  /// Subscribe to notifications for a user
  ResilientRealtimeChannel subscribeToNotifications({
    required String userId,
    required OnDataCallback onNotification,
    OnStateChangeCallback? onStateChange,
    OnErrorCallback? onError,
  }) {
    final channelName = 'notifications_$userId';
    
    final channel = ResilientRealtimeChannel(
      client: _client,
      channelName: channelName,
      table: 'notifications',
      filterColumn: 'user_id',
      filterValue: userId,
      event: PostgresChangeEvent.insert,
    );
    
    channel.subscribe(
      onData: onNotification,
      onStateChange: onStateChange,
      onError: onError,
    );
    
    _channels[channelName] = channel;
    return channel;
  }
  
  /// Unsubscribe from a specific channel
  void unsubscribe(String channelName) {
    final channel = _channels.remove(channelName);
    channel?.dispose();
  }
  
  /// Unsubscribe from all channels
  void disposeAll() {
    for (final channel in _channels.values) {
      channel.dispose();
    }
    _channels.clear();
    debugPrint('🔌 All realtime channels disposed');
  }
  
  /// Get connection state for a channel
  ConnectionState? getChannelState(String channelName) {
    return _channels[channelName]?.state;
  }
  
  /// Check if a channel is connected
  bool isChannelConnected(String channelName) {
    return _channels[channelName]?.isConnected ?? false;
  }
  
  /// Reconnect a specific channel
  void reconnectChannel(String channelName) {
    _channels[channelName]?.reconnect();
  }
  
  /// Reconnect all channels
  void reconnectAll() {
    for (final channel in _channels.values) {
      channel.reconnect();
    }
  }
}

// =============================================================================
// PENDING SYNC MANAGER (Pass 3 Final Polish)
// Automatically syncs queued offline actions when connection is restored
// =============================================================================

/// Manages syncing of offline-queued actions when connectivity is restored
class PendingSyncManager {
  final SupabaseClient _client;
  final void Function(String message, bool isError)? onSyncStatus;
  
  bool _isSyncing = false;
  
  PendingSyncManager(this._client, {this.onSyncStatus});
  
  /// Check if currently syncing
  bool get isSyncing => _isSyncing;
  
  /// Attempt to sync all pending actions
  /// Call this when network connectivity is restored
  Future<SyncResult> syncPendingActions() async {
    // Import here to avoid circular dependency
    final OfflineCacheService = _getOfflineCacheService();
    
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncedCount: 0,
        failedCount: 0,
      );
    }
    
    _isSyncing = true;
    int syncedCount = 0;
    int failedCount = 0;
    final List<String> errors = [];
    
    try {
      final actions = await OfflineCacheService.getPendingActions();
      
      if (actions.isEmpty) {
        _isSyncing = false;
        return SyncResult(
          success: true,
          message: 'No pending actions to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }
      
      onSyncStatus?.call('Syncing ${actions.length} pending action(s)...', false);
      debugPrint('🔄 Starting sync of ${actions.length} pending actions');
      
      for (final action in actions) {
        if (action.status == PendingSyncStatus.failed) {
          // Skip permanently failed actions
          failedCount++;
          continue;
        }
        
        try {
          await _executeAction(action);
          await OfflineCacheService.removePendingAction(action.id);
          syncedCount++;
          debugPrint('✅ Synced: ${action.displayDescription}');
        } catch (e) {
          final errorMsg = e.toString();
          await OfflineCacheService.markActionFailed(action.id, errorMsg);
          errors.add('${action.displayDescription}: $errorMsg');
          failedCount++;
          debugPrint('❌ Failed to sync ${action.displayDescription}: $e');
        }
      }
      
      final message = syncedCount > 0 
          ? 'Synced $syncedCount action(s)${failedCount > 0 ? ', $failedCount failed' : ''}'
          : 'Failed to sync $failedCount action(s)';
      
      onSyncStatus?.call(message, failedCount > 0 && syncedCount == 0);
      
      return SyncResult(
        success: syncedCount > 0 || failedCount == 0,
        message: message,
        syncedCount: syncedCount,
        failedCount: failedCount,
        errors: errors,
      );
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Execute a single pending action
  Future<void> _executeAction(PendingAction action) async {
    switch (action.type) {
      case PendingActionType.acceptOffer:
        await _syncAcceptOffer(action);
        break;
      case PendingActionType.rejectOffer:
        await _syncRejectOffer(action);
        break;
      case PendingActionType.cancelOrder:
        await _syncCancelOrder(action);
        break;
      case PendingActionType.sendMessage:
        await _syncSendMessage(action);
        break;
      case PendingActionType.updateProfile:
        await _syncUpdateProfile(action);
        break;
    }
  }
  
  Future<void> _syncAcceptOffer(PendingAction action) async {
    final offerId = action.resourceId;
    final deliveryAddress = action.payload['delivery_address'] as String?;
    final deliveryInstructions = action.payload['delivery_instructions'] as String?;
    
    // Call the accept offer endpoint
    await _client.rpc('accept_offer', params: {
      'p_offer_id': offerId,
      'p_delivery_address': deliveryAddress,
      'p_delivery_instructions': deliveryInstructions,
    });
  }
  
  Future<void> _syncRejectOffer(PendingAction action) async {
    final offerId = action.resourceId;
    
    await _client
        .from('offers')
        .update({'status': 'rejected'})
        .eq('id', offerId);
  }
  
  Future<void> _syncCancelOrder(PendingAction action) async {
    final orderId = action.resourceId;
    final reason = action.payload['reason'] as String?;
    
    await _client
        .from('orders')
        .update({
          'status': 'cancelled',
          'cancellation_reason': reason,
          'cancelled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }
  
  Future<void> _syncSendMessage(PendingAction action) async {
    final conversationId = action.payload['conversation_id'] as String?;
    final requestId = action.payload['request_id'] as String?;
    final shopId = action.payload['shop_id'] as String?;
    final content = action.payload['content'] as String?;
    final senderId = action.payload['sender_id'] as String?;
    
    if (requestId != null && shopId != null) {
      // Request chat message
      await _client.from('request_chat_messages').insert({
        'request_id': requestId,
        'shop_id': shopId,
        'sender_id': senderId,
        'content': content,
        'created_at': action.createdAt.toIso8601String(),
      });
    } else if (conversationId != null) {
      // Regular message
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'created_at': action.createdAt.toIso8601String(),
      });
    }
  }
  
  Future<void> _syncUpdateProfile(PendingAction action) async {
    final userId = action.resourceId;
    final updates = action.payload;
    
    await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId);
  }
  
  /// Helper to get OfflineCacheService (avoids import at top level)
  dynamic _getOfflineCacheService() {
    // This is a workaround - in production, use proper DI
    return OfflineCacheServiceHelper;
  }
}

/// Helper class to access OfflineCacheService static methods
class OfflineCacheServiceHelper {
  static Future<List<PendingAction>> getPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('pending_sync_queue');
    
    if (jsonString == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((e) => PendingAction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  static Future<void> removePendingAction(String actionId) async {
    final prefs = await SharedPreferences.getInstance();
    final actions = await getPendingActions();
    
    final filtered = actions.where((a) => a.id != actionId).toList();
    await prefs.setString(
      'pending_sync_queue', 
      jsonEncode(filtered.map((a) => a.toJson()).toList()),
    );
  }
  
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
      'pending_sync_queue', 
      jsonEncode(updated.map((a) => a.toJson()).toList()),
    );
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;
  
  SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
    this.errors = const [],
  });
}

/// Import these from offline_cache_service.dart
/// Re-exported here for convenience
enum PendingActionType {
  acceptOffer,
  rejectOffer,
  cancelOrder,
  sendMessage,
  updateProfile,
}

enum PendingSyncStatus {
  pending,
  syncing,
  failed,
  completed,
}

class PendingAction {
  final String id;
  final PendingActionType type;
  final String resourceId;
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
}
