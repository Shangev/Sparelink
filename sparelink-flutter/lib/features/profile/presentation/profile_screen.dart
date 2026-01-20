import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/widgets/responsive_page_layout.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;
  String? _userName;
  String? _userPhone;
  String? _userRole;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final storageService = ref.read(storageServiceProvider);
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // First try to get from local storage
      String? name = await storageService.getUserName();
      String? phone = await storageService.getUserPhone();
      String? role = await storageService.getUserRole();
      String? userId = await storageService.getUserId();
      
      // If local storage is empty or incomplete, fetch from Supabase
      if (userId == null || userId.isEmpty) {
        // Try to get current user from Supabase session
        final currentUser = supabaseService.currentUser;
        if (currentUser != null) {
          userId = currentUser.id;
          phone = currentUser.phone;
          
          // Fetch profile from Supabase
          final profile = await supabaseService.getProfile(userId);
          if (profile != null) {
            name = profile['full_name'] as String?;
            role = profile['role'] as String?;
            phone = phone ?? profile['phone'] as String?;
            
            // Save to local storage for next time
            await storageService.saveUserData(
              userId: userId,
              role: role ?? 'mechanic',
              name: name ?? '',
              phone: phone ?? '',
            );
          }
        }
      } else if (name == null || name.isEmpty) {
        // We have userId but missing other data, fetch from Supabase
        final profile = await supabaseService.getProfile(userId);
        if (profile != null) {
          name = profile['full_name'] as String?;
          role = role ?? profile['role'] as String?;
          phone = phone ?? profile['phone'] as String?;
          
          // Update local storage
          await storageService.saveUserData(
            userId: userId,
            role: role ?? 'mechanic',
            name: name ?? '',
            phone: phone ?? '',
          );
        }
      }
      
      if (mounted) {
        setState(() {
          _userName = name;
          _userPhone = phone;
          _userRole = role;
          _userId = userId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await context.push<bool>('/edit-profile');
    if (result == true) {
      _loadUserData(); // Reload user data if profile was updated
    }
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    setState(() => _isLoading = true);

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      // Sign out from Supabase
      await supabaseService.signOut();
      
      // Clear local storage
      await storageService.clearAll();

      if (mounted) {
        // Navigate to login screen
        context.go('/login');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully logged out'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    
    return ResponsivePageLayout(
      maxWidth: ResponsivePageLayout.mediumWidth,
      title: 'Profile',
      showBackButton: !isDesktop, // Only show back button on mobile
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Profile Avatar with Edit Button
          GestureDetector(
            onTap: () => _navigateToEditProfile(),
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentGreen.withOpacity(0.2),
                    border: Border.all(
                      color: AppTheme.accentGreen,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _userName?.isNotEmpty == true 
                          ? _userName![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF121212), width: 2),
                    ),
                    child: const Icon(LucideIcons.pencil, color: Colors.black, size: 14),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // User Name with Edit
          GestureDetector(
            onTap: () => _navigateToEditProfile(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _userName ?? 'Loading...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(LucideIcons.pencil, color: Colors.grey, size: 16),
              ],
            ),
          ),
          
          const SizedBox(height: 4),
          
          // User Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _userRole?.toUpperCase() ?? 'USER',
              style: const TextStyle(
                color: AppTheme.accentGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Desktop: Two column layout, Mobile: Single column
          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Profile Info
                Expanded(
                  child: _buildGlassCard(
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: LucideIcons.phone,
                          label: 'Phone',
                          value: _userPhone ?? 'Not set',
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildInfoRow(
                          icon: LucideIcons.user,
                          label: 'User ID',
                          value: _userId != null 
                              ? '${_userId!.substring(0, 8)}...'
                              : 'Not available',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Right column: Menu Items
                Expanded(
                  child: _buildGlassCard(
                    child: Column(
                      children: [
                        _buildMenuRow(
                          icon: LucideIcons.userPen,
                          label: 'Edit Profile',
                          onTap: () => _navigateToEditProfile(),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildMenuRow(
                          icon: LucideIcons.settings,
                          label: 'Settings',
                          onTap: () => context.push('/settings'),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildMenuRow(
                          icon: LucideIcons.circleHelp,
                          label: 'Help & Support',
                          onTap: () => context.push('/help-support'),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildMenuRow(
                          icon: LucideIcons.info,
                          label: 'About',
                          onTap: () => context.push('/about'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Mobile: Single column layout
            _buildGlassCard(
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: LucideIcons.phone,
                    label: 'Phone',
                    value: _userPhone ?? 'Not set',
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  _buildInfoRow(
                    icon: LucideIcons.user,
                    label: 'User ID',
                    value: _userId != null 
                        ? '${_userId!.substring(0, 8)}...'
                        : 'Not available',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            _buildGlassCard(
              child: Column(
                children: [
                  _buildMenuRow(
                    icon: LucideIcons.userPen,
                    label: 'Edit Profile',
                    onTap: () => _navigateToEditProfile(),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  _buildMenuRow(
                    icon: LucideIcons.settings,
                    label: 'Settings',
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  _buildMenuRow(
                    icon: LucideIcons.circleHelp,
                    label: 'Help & Support',
                    onTap: () => context.push('/help-support'),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  _buildMenuRow(
                    icon: LucideIcons.info,
                    label: 'About',
                    onTap: () => context.push('/about'),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 30),
          
          // Logout Button - constrained width on desktop
          SizedBox(
            width: isDesktop ? 300 : double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.red, width: 1),
                ),
              ),
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.red,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(LucideIcons.logOut),
              label: Text(_isLoading ? 'Logging out...' : 'Logout'),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.accentGreen, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

}
