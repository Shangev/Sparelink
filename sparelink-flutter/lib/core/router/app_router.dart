import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/camera/presentation/camera_screen_full.dart';
import '../../features/camera/presentation/vehicle_form_screen.dart';
import 'package:camera/camera.dart';
import '../../features/requests/presentation/my_requests_screen.dart';
import '../../features/requests/presentation/request_part_screen.dart';
import '../../features/requests/presentation/request_detail_screen.dart';
import '../../features/chat/presentation/chats_screen.dart';
import '../../features/chat/presentation/individual_chat_screen.dart';
import '../../features/chat/presentation/request_chat_screen.dart';
import '../../features/requests/presentation/request_chats_screen.dart';
import '../../features/marketplace/presentation/marketplace_results_screen.dart';
import '../../features/marketplace/presentation/shop_detail_screen.dart';
import '../../features/marketplace/presentation/quote_comparison_screen.dart';
import '../../shared/models/marketplace.dart';
import '../../features/orders/presentation/order_tracking_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/profile/presentation/help_support_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../shared/widgets/responsive_shell.dart';
import '../theme/app_theme.dart';

/// Auth state for the app
enum AuthState { initial, authenticated, unauthenticated }

/// Auth state notifier that listens to Supabase auth changes
class AuthNotifier extends ChangeNotifier {
  AuthState _authState = AuthState.initial;
  StreamSubscription<AuthState>? _authSubscription;
  
  AuthNotifier() {
    _init();
  }
  
  AuthState get authState => _authState;
  bool get isAuthenticated => _authState == AuthState.authenticated;
  bool get isInitialized => _authState != AuthState.initial;
  
  void _init() {
    // Check initial session
    final session = Supabase.instance.client.auth.currentSession;
    _authState = session != null ? AuthState.authenticated : AuthState.unauthenticated;
    notifyListeners();
    
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final newState = session != null ? AuthState.authenticated : AuthState.unauthenticated;
      
      if (_authState != newState) {
        _authState = newState;
        notifyListeners();
      }
    });
  }
  
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Auth notifier provider
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});

/// GoRouter Provider with auth guard
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);
  
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = authNotifier.authState;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isForgotPassword = state.matchedLocation == '/forgot-password';
      final isCompletingProfile = state.matchedLocation == '/complete-profile';
      
      // While checking auth state, stay on current route (will show loading)
      if (authState == AuthState.initial) {
        return null;
      }
      
      // Auth routes that don't require login
      final isAuthRoute = isLoggingIn || isRegistering || isForgotPassword || isCompletingProfile;
      
      // Not authenticated - redirect to login (unless already on auth route)
      if (authState == AuthState.unauthenticated) {
        return isAuthRoute ? null : '/login';
      }
      
      // Authenticated - redirect away from login/register to home
      if (authState == AuthState.authenticated && (isLoggingIn || isRegistering)) {
        return '/';
      }
      
      return null;
    },
    routes: [
      // Auth Routes (outside shell - no sidebar/nav)
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
      
      // Forgot Password
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) {
          final email = state.extra as String?;
          return ForgotPasswordScreen(email: email);
        },
      ),
      
      // Complete Profile (after phone/email verification)
      GoRoute(
        path: '/complete-profile',
        name: 'complete-profile',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          if (extra == null) {
            return const LoginScreen();
          }
          return CompleteProfileScreen(
            phone: extra['phone'] ?? '',
            userId: extra['userId'] ?? '',
            email: extra['email'],
          );
        },
      ),
      
      // Camera routes (full screen, outside shell)
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (context, state) => const CameraScreenFull(),
      ),
      GoRoute(
        path: '/camera/part',
        name: 'camera-part',
        builder: (context, state) => const CameraScreenFull(isPartPhoto: true),
      ),
      
      // Vehicle Form (full screen)
      GoRoute(
        path: '/vehicle-form',
        name: 'vehicle-form',
        builder: (context, state) {
          final images = state.extra as List<XFile>?;
          if (images == null) {
            return const HomeScreen();
          }
          return VehicleFormScreen(images: images);
        },
      ),
      
      // Main App Routes with Responsive Shell (sidebar on desktop, bottom nav on mobile)
      ShellRoute(
        builder: (context, state, child) {
          // Show loading while checking auth
          final authState = ref.read(authNotifierProvider).authState;
          if (authState == AuthState.initial) {
            return const _AuthLoadingScreen();
          }
          return ResponsiveShell(
            currentPath: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          // Home
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          
          // Request Part Flow
          GoRoute(
            path: '/request-part',
            name: 'request-part',
            builder: (context, state) => const RequestPartScreen(),
          ),
          
          // Marketplace Results
          GoRoute(
            path: '/marketplace',
            name: 'marketplace',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return MarketplaceResultsScreen(
                requestId: extra?['requestId'] ?? '',
              );
            },
          ),
          
          // Marketplace with dynamic ID parameter
          GoRoute(
            path: '/marketplace/:requestId',
            name: 'marketplace-detail',
            builder: (context, state) {
              final requestId = state.pathParameters['requestId']!;
              return MarketplaceResultsScreen(
                requestId: requestId,
              );
            },
          ),
          
          // Quote Comparison (side-by-side comparison view)
          GoRoute(
            path: '/compare-quotes/:requestId',
            name: 'compare-quotes',
            builder: (context, state) {
              final requestId = state.pathParameters['requestId']!;
              return QuoteComparisonScreen(requestId: requestId);
            },
          ),
          
          // Shop Detail with request context
          GoRoute(
            path: '/shop/:shopId/:requestId',
            name: 'shop-detail-with-request',
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
          
          // Shop Detail
          GoRoute(
            path: '/shop/:shopId',
            name: 'shop-detail',
            builder: (context, state) {
              final shopId = state.pathParameters['shopId']!;
              final extra = state.extra as Map<String, dynamic>?;
              return ShopDetailScreen(
                shopId: shopId,
                requestId: extra?['requestId'] ?? '',
              );
            },
          ),
          
          // My Requests
          GoRoute(
            path: '/my-requests',
            name: 'my-requests',
            builder: (context, state) => const MyRequestsScreen(),
          ),
          
          // Request Detail (for viewing accepted/completed requests)
          GoRoute(
            path: '/request/:requestId',
            name: 'request-detail',
            builder: (context, state) {
              final requestId = state.pathParameters['requestId']!;
              return RequestDetailScreen(requestId: requestId);
            },
          ),
          
          // Request Chats
          GoRoute(
            path: '/request-chats/:requestId',
            name: 'request-chats',
            builder: (context, state) {
              final requestId = state.pathParameters['requestId']!;
              return RequestChatsScreen(requestId: requestId);
            },
          ),
          
          // Request Chat (individual)
          GoRoute(
            path: '/request-chat/:chatId',
            name: 'request-chat',
            builder: (context, state) {
              final chatId = state.pathParameters['chatId']!;
              return RequestChatScreen(chatId: chatId);
            },
          ),
          
          // Chats List
          GoRoute(
            path: '/chats',
            name: 'chats',
            builder: (context, state) => const ChatsScreen(),
          ),
          
          // Individual Chat
          GoRoute(
            path: '/chat/:chatId',
            name: 'chat',
            builder: (context, state) {
              final chatId = state.pathParameters['chatId']!;
              return IndividualChatScreen(chatId: chatId);
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
          
          // Profile Routes
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/profile/edit',
            name: 'edit-profile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/help',
            name: 'help',
            builder: (context, state) => const HelpSupportScreen(),
          ),
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
      ),
    ],
  );
});

/// Loading screen shown while checking auth state
class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.build_circle_outlined,
                size: 48,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SpareLink',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppTheme.accentGreen,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
