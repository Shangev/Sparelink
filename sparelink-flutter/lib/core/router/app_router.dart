import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/camera/presentation/camera_screen.dart';
import '../../features/camera/presentation/camera_screen_full.dart';
import '../../features/camera/presentation/vehicle_form_screen.dart';
import 'package:camera/camera.dart';
import '../../features/requests/presentation/my_requests_screen.dart';
import '../../features/requests/presentation/request_part_screen.dart';
import '../../features/chat/presentation/chats_screen.dart';
import '../../features/chat/presentation/individual_chat_screen.dart';
import '../../features/chat/presentation/request_chat_screen.dart';
import '../../features/requests/presentation/request_chats_screen.dart';
// Marketplace flow imports
import '../../features/marketplace/presentation/marketplace_results_screen.dart';
import '../../features/marketplace/presentation/shop_detail_screen.dart';
import '../../features/orders/presentation/order_tracking_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/profile/presentation/help_support_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../shared/models/marketplace.dart';

/// GoRouter Provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // Complete Profile (after phone verification)
      GoRoute(
        path: '/complete-profile',
        name: 'complete-profile',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>;
          return CompleteProfileScreen(
            phone: extra['phone']!,
            userId: extra['userId']!,
          );
        },
      ),
      
      // Main App Routes
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // Request Part Flow (New)
      GoRoute(
        path: '/request-part',
        name: 'request-part',
        builder: (context, state) => const RequestPartScreen(),
      ),
      
      // Camera Flow (Legacy - kept for part photos)
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (context, state) => const CameraScreenFull(),
      ),
      
      // Camera for Part Photos (returns image URL)
      GoRoute(
        path: '/camera/part',
        name: 'camera-part',
        builder: (context, state) => const CameraScreenFull(isPartPhoto: true),
      ),
      
      // Vehicle Form (after camera)
      GoRoute(
        path: '/vehicle-form',
        name: 'vehicle-form',
        builder: (context, state) {
          final images = state.extra as List<XFile>;
          return VehicleFormScreen(images: images);
        },
      ),
      
      // Marketplace Results (after submitting request)
      GoRoute(
        path: '/marketplace/:requestId',
        name: 'marketplace',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          return MarketplaceResultsScreen(requestId: requestId);
        },
      ),
      
      // Shop Detail (from marketplace)
      GoRoute(
        path: '/shop/:shopId/:requestId',
        name: 'shop-detail',
        builder: (context, state) {
          final shopId = state.pathParameters['shopId']!;
          final requestId = state.pathParameters['requestId']!;
          final offer = state.extra as Offer?;
          return ShopDetailScreen(
            shopId: shopId,
            requestId: requestId,
            offer: offer,
          );
        },
      ),
      
      // Order Tracking
      GoRoute(
        path: '/order/:orderId',
        name: 'order-tracking',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      
      // My Requests
      GoRoute(
        path: '/my-requests',
        name: 'my-requests',
        builder: (context, state) => const MyRequestsScreen(),
      ),
      
      // Request Chats - Shows all shop responses to a request
      GoRoute(
        path: '/request-chats/:requestId',
        name: 'request-chats',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          return RequestChatsScreen(requestId: requestId);
        },
      ),
      
      // Chats
      GoRoute(
        path: '/chats',
        name: 'chats',
        builder: (context, state) => const ChatsScreen(),
      ),
      
      // Individual Chat Conversation (legacy)
      GoRoute(
        path: '/chat/:chatId',
        name: 'individual-chat',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final chatData = state.extra as Map<String, dynamic>?;
          // Check if this is a request chat or regular chat
          if (chatData == null) {
            // It's a request chat
            return RequestChatScreen(chatId: chatId);
          }
          return IndividualChatScreen(
            chatId: chatId,
            chatData: chatData,
          );
        },
      ),
      
      // Profile
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      
      // Edit Profile
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      
      // Settings
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      
      // Help & Support
      GoRoute(
        path: '/help-support',
        name: 'help-support',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      
      // About
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
      
      // Notifications
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    
    // Error handling
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

