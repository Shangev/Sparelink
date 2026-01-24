import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
