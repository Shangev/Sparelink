import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import 'sparelink_logo.dart';

/// Breakpoints for responsive design
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Navigation item model
class NavItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int? badgeCount;

  const NavItem({
    required this.path,
    required this.label,
    required this.icon,
    IconData? activeIcon,
    this.badgeCount,
  }) : activeIcon = activeIcon ?? icon;
}

/// Provider for navigation badge counts
final navBadgeProvider = StateProvider<Map<String, int>>((ref) => {});

/// Responsive shell that shows sidebar on desktop, bottom nav on mobile
class ResponsiveShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentPath;

  const ResponsiveShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  ConsumerState<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends ConsumerState<ResponsiveShell> {
  bool _isExpanded = true;

  List<NavItem> get _navItems {
    final badges = ref.watch(navBadgeProvider);
    return [
      NavItem(
        path: '/',
        label: 'Home',
        icon: LucideIcons.house,
        activeIcon: LucideIcons.house,
      ),
      NavItem(
        path: '/request-part',
        label: 'Request Part',
        icon: LucideIcons.plus,
        activeIcon: LucideIcons.plus,
      ),
      NavItem(
        path: '/my-requests',
        label: 'My Requests',
        icon: LucideIcons.clipboardList,
        activeIcon: LucideIcons.clipboardList,
        badgeCount: badges['requests'],
      ),
      NavItem(
        path: '/chats',
        label: 'Chats',
        icon: LucideIcons.messageSquare,
        activeIcon: LucideIcons.messageSquare,
        badgeCount: badges['chats'],
      ),
      NavItem(
        path: '/profile',
        label: 'Profile',
        icon: LucideIcons.user,
        activeIcon: LucideIcons.user,
      ),
    ];
  }

  bool _isPathActive(String itemPath) {
    if (itemPath == '/') {
      return widget.currentPath == '/';
    }
    return widget.currentPath.startsWith(itemPath);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= Breakpoints.tablet;

    if (isDesktop) {
      return _buildDesktopLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  /// Desktop layout with sidebar
  Widget _buildDesktopLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideDesktop = screenWidth >= Breakpoints.desktop;

    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isExpanded ? 260 : 80,
            child: _buildSidebar(context, isWideDesktop),
          ),
          // Vertical divider
          Container(
            width: 1,
            color: Colors.white.withOpacity(0.1),
          ),
          // Main content
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  /// Sidebar for desktop
  Widget _buildSidebar(BuildContext context, bool isWideDesktop) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Column(
        children: [
          // Header with logo
          _buildSidebarHeader(),
          const SizedBox(height: 8),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                ..._navItems.map((item) => _buildSidebarItem(item)),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                // Additional items
                _buildSidebarItem(const NavItem(
                  path: '/notifications',
                  label: 'Notifications',
                  icon: LucideIcons.bell,
                )),
                _buildSidebarItem(const NavItem(
                  path: '/settings',
                  label: 'Settings',
                  icon: LucideIcons.settings,
                )),
                _buildSidebarItem(NavItem(
                  path: '/help',
                  label: 'Help & Support',
                  icon: LucideIcons.circleHelp,
                )),
              ],
            ),
          ),
          // Footer
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const SpareLinkLogo(size: 36, color: Colors.white),
          if (_isExpanded) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'SpareLink',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
          // Collapse/Expand button
          IconButton(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            icon: Icon(
              _isExpanded ? LucideIcons.panelLeftClose : LucideIcons.panelLeftOpen,
              color: Colors.white54,
              size: 20,
            ),
            tooltip: _isExpanded ? 'Collapse sidebar' : 'Expand sidebar',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(NavItem item) {
    final isActive = _isPathActive(item.path);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(item.path),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 16 : 12,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.accentGreen.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AppTheme.accentGreen.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isActive ? item.activeIcon : item.icon,
                      color: isActive ? AppTheme.accentGreen : Colors.white54,
                      size: 22,
                    ),
                    if (item.badgeCount != null && item.badgeCount! > 0)
                      Positioned(
                        top: -6,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            item.badgeCount! > 99 ? '99+' : '${item.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? AppTheme.accentGreen : Colors.white70,
                        fontSize: 15,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (item.badgeCount != null && item.badgeCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.badgeCount! > 99 ? '99+' : '${item.badgeCount}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: _isExpanded
          ? Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    color: AppTheme.accentGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mechanic',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'View profile',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(
                    LucideIcons.chevronRight,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),
              ],
            )
          : IconButton(
              onPressed: () => context.go('/profile'),
              icon: const Icon(
                LucideIcons.user,
                color: Colors.white54,
                size: 22,
              ),
            ),
    );
  }

  /// Mobile layout with bottom navigation
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: widget.child,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _navItems.map((item) {
          final isActive = _isPathActive(item.path);
          // Use Grid icon for Home on mobile
          final icon = item.path == '/' ? LucideIcons.layoutGrid : item.icon;
          return _buildNavItem(
            icon: icon,
            label: item.label,
            isActive: isActive,
            badge: item.badgeCount ?? 0,
            onTap: () => context.go(item.path),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    bool isActive = false,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.white38,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Extension to get responsive layout info easily
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  bool get isMobile => screenWidth < Breakpoints.mobile;
  bool get isTablet => screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.desktop;
  bool get isDesktop => screenWidth >= Breakpoints.tablet;
  bool get isWideDesktop => screenWidth >= Breakpoints.desktop;
}
