import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';

/// Professional empty state widget with illustration
class EmptyState extends StatelessWidget {
  final EmptyStateType type;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(type);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration
            _buildIllustration(config),
            const SizedBox(height: 24),
            
            // Title
            Text(
              title ?? config.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Message
            Text(
              message ?? config.message,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(config.actionIcon, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(_EmptyStateConfig config) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background pattern
          ...List.generate(3, (index) {
            final size = 120.0 - (index * 30);
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: config.color.withOpacity(0.1 + (index * 0.05)),
                  width: 1,
                ),
              ),
            );
          }),
          // Main icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              config.icon,
              size: 36,
              color: config.color,
            ),
          ),
          // Secondary icon (decorative)
          if (config.secondaryIcon != null)
            Positioned(
              right: 30,
              top: 25,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  shape: BoxShape.circle,
                  border: Border.all(color: config.color.withOpacity(0.3)),
                ),
                child: Icon(
                  config.secondaryIcon,
                  size: 18,
                  color: config.color.withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  _EmptyStateConfig _getConfig(EmptyStateType type) {
    switch (type) {
      case EmptyStateType.noRequests:
        return _EmptyStateConfig(
          icon: LucideIcons.clipboardList,
          secondaryIcon: LucideIcons.plus,
          title: 'No Requests Yet',
          message: 'Start by requesting a part. Snap a photo or describe what you need.',
          color: AppTheme.accentGreen,
          actionIcon: LucideIcons.plus,
        );
      case EmptyStateType.noQuotes:
        return _EmptyStateConfig(
          icon: LucideIcons.messageSquare,
          secondaryIcon: LucideIcons.clock,
          title: 'Waiting for Quotes',
          message: 'Shops are reviewing your request. You\'ll be notified when quotes arrive.',
          color: Colors.blue,
          actionIcon: LucideIcons.refreshCw,
        );
      case EmptyStateType.noChats:
        return _EmptyStateConfig(
          icon: LucideIcons.messagesSquare,
          secondaryIcon: null,
          title: 'No Conversations',
          message: 'When you receive quotes, you can chat directly with shops here.',
          color: Colors.purple,
          actionIcon: LucideIcons.search,
        );
      case EmptyStateType.noNotifications:
        return _EmptyStateConfig(
          icon: LucideIcons.bell,
          secondaryIcon: null,
          title: 'All Caught Up!',
          message: 'You have no new notifications. We\'ll let you know when something happens.',
          color: Colors.orange,
          actionIcon: LucideIcons.refreshCw,
        );
      case EmptyStateType.noSearchResults:
        return _EmptyStateConfig(
          icon: LucideIcons.searchX,
          secondaryIcon: null,
          title: 'No Results Found',
          message: 'Try adjusting your search or filters to find what you\'re looking for.',
          color: Colors.grey,
          actionIcon: LucideIcons.x,
        );
      case EmptyStateType.noShops:
        return _EmptyStateConfig(
          icon: LucideIcons.store,
          secondaryIcon: LucideIcons.mapPin,
          title: 'No Shops Nearby',
          message: 'We couldn\'t find shops in your area. Try expanding your search radius.',
          color: Colors.red,
          actionIcon: LucideIcons.mapPin,
        );
      case EmptyStateType.noOrders:
        return _EmptyStateConfig(
          icon: LucideIcons.package,
          secondaryIcon: null,
          title: 'No Orders Yet',
          message: 'When you accept a quote, your orders will appear here for tracking.',
          color: Colors.teal,
          actionIcon: LucideIcons.search,
        );
      case EmptyStateType.noSavedVehicles:
        return _EmptyStateConfig(
          icon: LucideIcons.car,
          secondaryIcon: LucideIcons.plus,
          title: 'No Saved Vehicles',
          message: 'Save your vehicles for faster part requests in the future.',
          color: AppTheme.accentGreen,
          actionIcon: LucideIcons.plus,
        );
      case EmptyStateType.offline:
        return _EmptyStateConfig(
          icon: LucideIcons.wifiOff,
          secondaryIcon: null,
          title: 'You\'re Offline',
          message: 'Check your internet connection and try again.',
          color: Colors.grey,
          actionIcon: LucideIcons.refreshCw,
        );
      case EmptyStateType.error:
        return _EmptyStateConfig(
          icon: LucideIcons.circleAlert,
          secondaryIcon: null,
          title: 'Something Went Wrong',
          message: 'We had trouble loading this page. Please try again.',
          color: Colors.red,
          actionIcon: LucideIcons.refreshCw,
        );
    }
  }
}

enum EmptyStateType {
  noRequests,
  noQuotes,
  noChats,
  noNotifications,
  noSearchResults,
  noShops,
  noOrders,
  noSavedVehicles,
  offline,
  error,
}

class _EmptyStateConfig {
  final IconData icon;
  final IconData? secondaryIcon;
  final String title;
  final String message;
  final Color color;
  final IconData actionIcon;

  _EmptyStateConfig({
    required this.icon,
    this.secondaryIcon,
    required this.title,
    required this.message,
    required this.color,
    required this.actionIcon,
  });
}
