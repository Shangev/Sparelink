import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/haptic_service.dart';

// =============================================================================
// ACCESSIBLE ICON BUTTON
// Pass 2 Phase 5 Implementation
// Provides icon buttons with proper tap targets (48x48 minimum) and semantics
// =============================================================================

/// An icon button that meets accessibility guidelines:
/// - Minimum 48x48 tap target (WCAG 2.1 Success Criterion 2.5.5)
/// - Semantic label for screen readers
/// - Optional haptic feedback
/// - Optional tooltip
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String? tooltip;
  final double iconSize;
  final double tapTargetSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? splashColor;
  final bool enableHaptics;
  final EdgeInsetsGeometry? padding;
  
  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.tooltip,
    this.iconSize = 24.0,
    this.tapTargetSize = 48.0, // WCAG minimum
    this.iconColor,
    this.backgroundColor,
    this.splashColor,
    this.enableHaptics = true,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(tapTargetSize / 2),
        child: InkWell(
          onTap: onPressed != null
              ? () {
                  if (enableHaptics) {
                    HapticService.light();
                  }
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(tapTargetSize / 2),
          splashColor: splashColor ?? Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            width: tapTargetSize,
            height: tapTargetSize,
            padding: padding,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? (onPressed != null 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.5)),
            ),
          ),
        ),
      ),
    );
    
    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    
    return button;
  }
}

/// A back button with proper accessibility
class AccessibleBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color? iconColor;
  
  const AccessibleBackButton({
    super.key,
    this.onPressed,
    this.semanticLabel,
    this.iconColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return AccessibleIconButton(
      icon: Icons.arrow_back,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      semanticLabel: semanticLabel ?? 'Go back',
      tooltip: 'Back',
      iconColor: iconColor,
    );
  }
}

/// A close button with proper accessibility
class AccessibleCloseButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color? iconColor;
  
  const AccessibleCloseButton({
    super.key,
    this.onPressed,
    this.semanticLabel,
    this.iconColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return AccessibleIconButton(
      icon: Icons.close,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      semanticLabel: semanticLabel ?? 'Close',
      tooltip: 'Close',
      iconColor: iconColor,
    );
  }
}

/// A menu button (hamburger) with proper accessibility
class AccessibleMenuButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color? iconColor;
  
  const AccessibleMenuButton({
    super.key,
    this.onPressed,
    this.semanticLabel,
    this.iconColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return AccessibleIconButton(
      icon: Icons.menu,
      onPressed: onPressed ?? () => Scaffold.of(context).openDrawer(),
      semanticLabel: semanticLabel ?? 'Open menu',
      tooltip: 'Menu',
      iconColor: iconColor,
    );
  }
}

/// A more/overflow button with proper accessibility
class AccessibleMoreButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color? iconColor;
  
  const AccessibleMoreButton({
    super.key,
    this.onPressed,
    this.semanticLabel,
    this.iconColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return AccessibleIconButton(
      icon: Icons.more_vert,
      onPressed: onPressed,
      semanticLabel: semanticLabel ?? 'More options',
      tooltip: 'More',
      iconColor: iconColor,
    );
  }
}

/// A notification bell button with optional badge
class AccessibleNotificationButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final int unreadCount;
  final String? semanticLabel;
  final Color? iconColor;
  final Color? badgeColor;
  
  const AccessibleNotificationButton({
    super.key,
    this.onPressed,
    this.unreadCount = 0,
    this.semanticLabel,
    this.iconColor,
    this.badgeColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final label = unreadCount > 0
        ? '${semanticLabel ?? 'Notifications'}, $unreadCount unread'
        : semanticLabel ?? 'Notifications';
    
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed != null
              ? () {
                  HapticService.light();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 24,
                  color: iconColor ?? Colors.white,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: badgeColor ?? const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A search button with proper accessibility
class AccessibleSearchButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color? iconColor;
  
  const AccessibleSearchButton({
    super.key,
    this.onPressed,
    this.semanticLabel,
    this.iconColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return AccessibleIconButton(
      icon: Icons.search,
      onPressed: onPressed,
      semanticLabel: semanticLabel ?? 'Search',
      tooltip: 'Search',
      iconColor: iconColor,
    );
  }
}

/// A filter button with proper accessibility
class AccessibleFilterButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isActive;
  final String? semanticLabel;
  final Color? iconColor;
  final Color? activeColor;
  
  const AccessibleFilterButton({
    super.key,
    this.onPressed,
    this.isActive = false,
    this.semanticLabel,
    this.iconColor,
    this.activeColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final label = isActive
        ? '${semanticLabel ?? 'Filter'}, active'
        : semanticLabel ?? 'Filter';
    
    return AccessibleIconButton(
      icon: Icons.filter_list,
      onPressed: onPressed,
      semanticLabel: label,
      tooltip: 'Filter',
      iconColor: isActive 
          ? (activeColor ?? const Color(0xFF4CAF50))
          : iconColor,
    );
  }
}

/// A refresh button with proper accessibility
class AccessibleRefreshButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? semanticLabel;
  final Color? iconColor;
  
  const AccessibleRefreshButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.semanticLabel,
    this.iconColor,
  });
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Semantics(
        label: 'Loading',
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    
    return AccessibleIconButton(
      icon: Icons.refresh,
      onPressed: onPressed,
      semanticLabel: semanticLabel ?? 'Refresh',
      tooltip: 'Refresh',
      iconColor: iconColor,
    );
  }
}
