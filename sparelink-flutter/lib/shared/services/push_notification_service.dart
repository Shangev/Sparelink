import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Firebase imports - uncomment when Firebase is configured
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

/// Push Notification Service Provider
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

// Background message handler (must be top-level function)
// Uncomment when Firebase is configured
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   debugPrint('🔔 [Background] Message received: ${message.notification?.title}');
// }

/// Push Notification Service
/// Handles Firebase Cloud Messaging for real-time push notifications
/// 
/// SETUP INSTRUCTIONS:
/// 1. Create a Firebase project at https://console.firebase.google.com
/// 2. Run: dart pub global activate flutterfire_cli
/// 3. Run: flutterfire configure
/// 4. Uncomment Firebase imports and code in this file
/// 5. Uncomment firebase_core and firebase_messaging in pubspec.yaml
/// 6. Run: flutter pub get
class PushNotificationService {
  // Uncomment when Firebase is configured:
  // final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _isInitialized = false;
  
  /// Get the current FCM token
  String? get fcmToken => _fcmToken;
  
  /// Check if push notifications are available
  bool get isAvailable => _isInitialized;
  
  /// Initialize push notifications
  /// Returns false if Firebase is not configured
  Future<bool> initialize() async {
    // Firebase not configured yet - return false
    // Uncomment the code below once Firebase is set up
    debugPrint('⚠️ [PushNotification] Firebase not configured. Push notifications disabled.');
    debugPrint('📋 [PushNotification] See setup instructions in push_notification_service.dart');
    return false;
    
    /* UNCOMMENT THIS BLOCK WHEN FIREBASE IS CONFIGURED:
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
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ [PushNotification] Failed to initialize: $e');
      return false;
    }
    */
  }
  
  /* UNCOMMENT WHEN FIREBASE IS CONFIGURED:
  /// Set up message handlers for foreground and background
  void _setupMessageHandlers() {
    // Background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [Foreground] Message received: ${message.notification?.title}');
      _handleMessage(message);
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
  
  /// Handle incoming message (foreground)
  void _handleMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    
    debugPrint('📬 Notification: ${notification?.title} - ${notification?.body}');
    debugPrint('📦 Data: $data');
    
    // You can show a local notification here if needed
    // Or update app state to show in-app notification
  }
  
  /// Handle notification tap
  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    
    // Navigate based on notification type
    final type = data['type'];
    final referenceId = data['reference_id'];
    
    debugPrint('🔗 Navigate to: type=$type, id=$referenceId');
    
    // Navigation will be handled by the app's navigation system
    // You can use a callback or stream to communicate with the UI
  }
  */
  
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
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ [PushNotification] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ [PushNotification] Failed to subscribe to topic: $e');
    }
  }
  
  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ [PushNotification] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ [PushNotification] Failed to unsubscribe from topic: $e');
    }
  }
}
