import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/sparelink_logo.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isCheckingRole = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final storageService = ref.read(storageServiceProvider);
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // First check local storage
      String? role = await storageService.getUserRole();
      
      // If no role in storage, check Supabase
      if (role == null || role.isEmpty) {
        final user = supabaseService.currentUser;
        if (user != null) {
          final profile = await supabaseService.getProfile(user.id);
          role = profile?['role'] as String?;
          
          // Save to storage if found
          if (role != null) {
            await storageService.saveUserData(
              userId: user.id,
              role: role,
              name: profile?['full_name'] ?? '',
              phone: profile?['phone'] ?? '',
            );
          }
        }
      }
      
      // If user is a shop, redirect to shop dashboard
      if (role == 'shop') {
        final session = Supabase.instance.client.auth.currentSession;
        await _redirectToShopDashboard(session?.accessToken);
        return;
      }
      
      // User is mechanic, continue showing home screen
      if (mounted) {
        setState(() => _isCheckingRole = false);
      }
    } catch (e) {
      // On error, just show the home screen
      if (mounted) {
        setState(() => _isCheckingRole = false);
      }
    }
  }

  Future<void> _redirectToShopDashboard(String? accessToken) async {
    const shopDashboardUrl = 'http://localhost:3000';
    
    if (kIsWeb) {
      final uri = Uri.parse('$shopDashboardUrl/dashboard?token=$accessToken');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        _showShopRedirectDialog();
      }
    } else {
      _showShopRedirectDialog();
    }
  }

  void _showShopRedirectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        title: const Text('Shop Account Detected', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This app is for mechanics to request parts.',
              style: TextStyle(color: AppTheme.lightGray),
            ),
            SizedBox(height: 16),
            Text(
              'As a shop owner, please use the Shop Dashboard to manage your business:',
              style: TextStyle(color: AppTheme.lightGray),
            ),
            SizedBox(height: 12),
            Text(
              'http://localhost:3000',
              style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Log out and go to login
              await Supabase.instance.client.auth.signOut();
              final storageService = ref.read(storageServiceProvider);
              await storageService.clearAll();
              if (mounted) {
                context.go('/login');
              }
            },
            child: const Text('Sign Out'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Try to open dashboard
              const url = 'http://localhost:3000';
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: const Text('Open Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking role
    if (_isCheckingRole) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpareLinkLogo(size: 64, color: Colors.white),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    return _buildHomeContent(context);
  }

  Widget _buildHomeContent(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Background - Dark gradient/radial effect to match image
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFF2C2C2C), Color(0xFF000000)],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Fixed Header Bar - Only logo and notification icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo Section
                      Row(
                        children: [
                          const SpareLinkLogo(size: 32, color: Colors.white),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'SpareLink',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Mechanics',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  height: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Notification Bell - Navigate to notifications
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.bell, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content - Hero text and grid cards
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        // Hero Text
                        const Text(
                          'Find any part.\nDelivered fast.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Grid Section - Using GridView with shrinkWrap
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.82,
                          children: [
                            // Request a Part -> New request flow
                            _buildClickableGridCard(
                              iconWidget: const SpareLinkLogo(size: 48, color: Colors.white),
                              title: 'Request a Part',
                              subtitle: 'Find parts quickly from nearby shops',
                              onTap: () => context.push('/request-part'),
                            ),
                            // My Requests
                            _buildClickableGridCard(
                              icon: LucideIcons.clipboardList,
                              title: 'My Requests',
                              subtitle: 'Track offers and deliveries',
                              onTap: () => context.push('/my-requests'),
                            ),
                            // Deliveries -> Order Tracking (show snackbar for now as it needs orderId)
                            _buildClickableGridCard(
                              icon: LucideIcons.truck,
                              title: 'Deliveries',
                              subtitle: 'Track your incoming parts',
                              onTap: () {
                                // Navigate to my-requests where user can select an order to track
                                context.push('/my-requests');
                              },
                            ),
                            // Chats
                            _buildClickableGridCard(
                              icon: LucideIcons.messageCircle,
                              title: 'Chats',
                              subtitle: 'Confirm part details before ordering.',
                              onTap: () => context.push('/chats'),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 20, top: 10),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home - Already here, stays active
            _buildNavItemClickable(
              icon: LucideIcons.grid3x3,
              label: 'Home',
              isActive: true,
              onTap: () {}, // Already on home
            ),
            // My Requests
            _buildNavItemClickable(
              icon: LucideIcons.clipboardList,
              label: 'My Requests',
              onTap: () => context.push('/my-requests'),
            ),
            // Chats
            _buildNavItemClickable(
              icon: LucideIcons.messageSquare,
              label: 'Chats',
              onTap: () => context.push('/chats'),
            ),
            // Profile
            _buildNavItemClickable(
              icon: LucideIcons.user,
              label: 'Profile',
              onTap: () => context.push('/profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableGridCard({
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget ?? Icon(icon, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemClickable({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget ?? Icon(icon, color: isActive ? Colors.white : Colors.white38, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
