import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'settings_service.dart';

/// Push Notification Service Provider
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 [Background] Message received: ${message.notification?.title}');
  // Background messages are handled by the system notification tray
  // The app will handle navigation when opened from notification
}

/// Push Notification Service
/// Handles Firebase Cloud Messaging for real-time push notifications
/// 
/// SETUP INSTRUCTIONS:
/// 1. Create a Firebase project at https://console.firebase.google.com
/// 2. Run: dart pub global activate flutterfire_cli
/// 3. Run: flutterfire configure
/// 4. Add google-services.json (Android) and GoogleService-Info.plist (iOS)
/// 5. Run: flutter pub get
class PushNotificationService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _isInitialized = false;
  
  // Callback for handling notification taps
  Function(String type, String? referenceId)? onNotificationTap;
  
  // Callback for showing in-app notifications
  Function(String title, String body, Map<String, dynamic> data)? onForegroundMessage;
  
  PushNotificationService(this._ref);
  
  /// Get the current FCM token
  String? get fcmToken => _fcmToken;
  
  /// Check if push notifications are available
  bool get isAvailable => _isInitialized;
  
  /// Initialize push notifications
  /// Returns false if Firebase is not configured or permission denied
  Future<bool> initialize() async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      debugPrint('🔔 [PushNotification] Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        debugPrint('🔔 [PushNotification] FCM Token: $_fcmToken');
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          debugPrint('🔔 [PushNotification] Token refreshed: $newToken');
          _saveTokenToDatabase(newToken);
        });
        
        // Set up message handlers
        _setupMessageHandlers();
        
        // Save token to database
        if (_fcmToken != null) {
          await _saveTokenToDatabase(_fcmToken!);
        }
        
        _isInitialized = true;
        debugPrint('✅ [PushNotification] Initialized successfully');
        return true;
      }
      
      debugPrint('⚠️ [PushNotification] Permission not granted');
      return false;
    } catch (e) {
      debugPrint('❌ [PushNotification] Failed to initialize: $e');
      return false;
    }
  }
  
  /// Set up message handlers for foreground and background
  void _setupMessageHandlers() {
    // Background message handler is set up in main.dart
    // FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [Foreground] Message received: ${message.notification?.title}');
      _handleForegroundMessage(message);
    });
    
    // Handle message tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 [MessageTap] User tapped notification: ${message.notification?.title}');
      _handleMessageTap(message);
    });
    
    // Check if app was opened from a notification
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('🔔 [Initial] App opened from notification: ${message.notification?.title}');
        _handleMessageTap(message);
      }
    });
  }
  
  /// Handle incoming message when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final notificationType = data['type'] as String? ?? 'general';
    
    debugPrint('📬 Notification: ${notification?.title} - ${notification?.body}');
    debugPrint('📦 Data: $data');
    
    // Check user preferences before showing notification
    final settingsService = _ref.read(settingsServiceProvider);
    
    // Check if we should deliver this notification based on user preferences
    if (!settingsService.shouldDeliverNotification(notificationType)) {
      debugPrint('🔕 [PushNotification] Notification suppressed by user preferences');
      return;
    }
    
    // Get the appropriate sound for this notification type
    final sound = settingsService.getSoundForType(notificationType);
    debugPrint('🔊 [PushNotification] Using sound: ${sound.displayName}');
    
    // Call the foreground message callback if set
    if (onForegroundMessage != null && notification != null) {
      onForegroundMessage!(
        notification.title ?? 'Notification',
        notification.body ?? '',
        data,
      );
    }
  }
  
  /// Handle notification tap (opens app to specific screen)
  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    
    // Navigate based on notification type
    final type = data['type'] as String?;
    final referenceId = data['reference_id'] as String?;
    
    debugPrint('🔗 Navigate to: type=$type, id=$referenceId');
    
    // Call the navigation callback if set
    if (onNotificationTap != null && type != null) {
      onNotificationTap!(type, referenceId);
    }
  }
  
  /// Check if a notification should be shown based on user settings
  bool shouldShowNotification(String notificationType) {
    final settingsService = _ref.read(settingsServiceProvider);
    return settingsService.shouldDeliverNotification(notificationType);
  }
  
  /// Get the notification sound for a specific type
  NotificationSound getNotificationSound(String notificationType) {
    final settingsService = _ref.read(settingsServiceProvider);
    return settingsService.getSoundForType(notificationType);
  }
  
  /// Save FCM token to Supabase for server-side push
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Determine platform
      String platform = 'unknown';
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          platform = 'android';
        } else if (Platform.isIOS) {
          platform = 'ios';
        }
      } else {
        platform = 'web';
      }
      
      await Supabase.instance.client
          .from('user_fcm_tokens')
          .upsert({
            'user_id': userId,
            'token': token,
            'platform': platform,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
      
      debugPrint('✅ [PushNotification] Token saved to database');
    } catch (e) {
      debugPrint('❌ [PushNotification] Failed to save token: $e');
    }
  }
  
  /// Remove FCM token (on logout)
  Future<void> removeToken() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || _fcmToken == null) return;
      
      await Supabase.instance.client
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', _fcmToken!);
      
      debugPrint('✅ [PushNotification] Token removed from database');
    } catch (e) {
      debugPrint('❌ [PushNotification] Failed to remove token: $e');
    }
  }
  
  /// Subscribe to a topic (e.g., for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    if (!_isInitialized) return;
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ [PushNotification] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ [PushNotification] Failed to subscribe to topic: $e');
    }
  }
  
  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isInitialized) return;
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ [PushNotification] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ [PushNotification] Failed to unsubscribe from topic: $e');
    }
  }
  
  /// Request notification permissions (can be called again if initially denied)
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('❌ [PushNotification] Failed to request permission: $e');
      return false;
    }
  }
  
  /// Get current notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _messaging.getNotificationSettings();
  }
  
  /// Check if notifications are enabled at the system level
  Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
           settings.authorizationStatus == AuthorizationStatus.provisional;
  }
}
