import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/responsive_page_layout.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/empty_state.dart';

/// Notifications Screen - Shows all user notifications
/// Categories: Quotes, Orders, Messages, System
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Design constants - UX-01 FIX: Use AppTheme colors for consistency
  static const Color _backgroundColor = Color(0xFF000000);  // AppTheme.primaryBlack
  static const Color _cardBackground = Color(0xFF1A1A1A);   // AppTheme.darkGray
  static const Color _subtitleGray = Color(0xFF888888);     // AppTheme.lightGray
  static const Color _accentGreen = Color(0xFF4CAF50);      // AppTheme.accentGreen

  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  String _selectedFilter = 'all';
  String? _currentUserId;
  String? _error;
  RealtimeChannel? _notificationSubscription;

  final List<Map<String, dynamic>> _filters = [
    {'id': 'all', 'label': 'All', 'icon': LucideIcons.bell},
    {'id': 'quote', 'label': 'Offers', 'icon': LucideIcons.tag},
    {'id': 'order', 'label': 'Orders', 'icon': LucideIcons.package},
    {'id': 'message', 'label': 'Messages', 'icon': LucideIcons.messageCircle},
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storageService = ref.read(storageServiceProvider);
      final supabaseService = ref.read(supabaseServiceProvider);
      
      _currentUserId = await storageService.getUserId();
      
      if (_currentUserId == null) {
        setState(() {
          _error = 'Please log in to view notifications';
          _isLoading = false;
        });
        return;
      }

      final notifications = await supabaseService.getUserNotifications(_currentUserId!);
      
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });

      // Subscribe to new notifications
      _subscribeToNotifications();
    } catch (e) {
      setState(() {
        _error = 'Failed to load notifications';
        _isLoading = false;
      });
    }
  }

  void _subscribeToNotifications() {
    if (_currentUserId == null) return;
    
    final supabaseService = ref.read(supabaseServiceProvider);
    _notificationSubscription = supabaseService.subscribeToNotifications(
      _currentUserId!,
      (newNotification) {
        setState(() {
          _notifications.insert(0, newNotification);
        });
      },
    );
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'all') return _notifications;
    return _notifications.where((n) => n['type'] == _selectedFilter).toList();
  }

  Future<void> _markAllAsRead() async {
    if (_currentUserId == null) return;
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      await supabaseService.markAllNotificationsAsRead(_currentUserId!);
      
      // Update local state
      setState(() {
        for (var notification in _notifications) {
          notification['read'] = true;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: _accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark notifications as read'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                _buildHeader(isDesktop),
                _buildFilterTabs(),
                Expanded(
                  child: _isLoading
                      ? _buildSkeletonList()
                      : _filteredNotifications.isEmpty
                          ? _buildEmptyState()
                          : _buildNotificationsList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back Button - hide on desktop (sidebar provides navigation)
          if (!isDesktop) ...[
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 16),
          ],
          
          // Title
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Mark All Read Button
          if (_notifications.isNotEmpty)
            GestureDetector(
              onTap: _markAllAsRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Mark all read',
                  style: TextStyle(color: _accentGreen, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter['id'];
          
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter['id']),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _accentGreen : _cardBackground,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? _accentGreen : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    color: isSelected ? Colors.white : _subtitleGray,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    filter['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _subtitleGray,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8, // Show 8 skeleton items
      itemBuilder: (context, index) => const SkeletonNotificationItem(),
    );
  }

  Widget _buildEmptyState() {
    // Use custom message based on filter, but leverage EmptyState widget
    if (_selectedFilter == 'all') {
      return EmptyState(
        type: EmptyStateType.noNotifications,
        actionLabel: 'Request a Part',
        onAction: () => context.push('/request-part'),
      );
    }
    
    // Custom messages for filtered views
    String message;
    switch (_selectedFilter) {
      case 'quote':
        message = 'No offer notifications yet. You\'ll be notified when shops respond to your requests.';
        break;
      case 'order':
        message = 'No order notifications yet. Order updates will appear here.';
        break;
      case 'message':
        message = 'No message notifications yet. New messages from shops will appear here.';
        break;
      default:
        message = 'No notifications in this category.';
    }
    
    return EmptyState(
      type: EmptyStateType.noNotifications,
      title: 'No ${_filters.firstWhere((f) => f['id'] == _selectedFilter)['label']} Notifications',
      message: message,
      actionLabel: 'Request a Part',
      onAction: () => context.push('/request-part'),
    );
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: _accentGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = _filteredNotifications[index];
          return _NotificationCard(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onDismiss: () => _dismissNotification(notification),
          );
        },
      ),
    );
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read in Supabase
    final notificationId = notification['id']?.toString();
    if (notificationId != null) {
      try {
        final supabaseService = ref.read(supabaseServiceProvider);
        await supabaseService.markNotificationAsRead(notificationId);
      } catch (e) {
        // Silently fail - not critical
      }
    }
    
    // Update local state
    setState(() {
      notification['read'] = true;
    });

    // Navigate based on type
    final type = notification['type'] as String?;
    final referenceId = notification['reference_id'] as String?;

    if (referenceId == null) return;

    switch (type) {
      case 'quote':
        context.push('/marketplace/$referenceId');
        break;
      case 'order':
        context.push('/order/$referenceId');
        break;
      case 'message':
        context.push('/chat/$referenceId');
        break;
    }
  }

  Future<void> _dismissNotification(Map<String, dynamic> notification) async {
    final notificationId = notification['id']?.toString();
    
    // Remove from local state immediately
    setState(() {
      _notifications.remove(notification);
    });
    
    // Delete from Supabase
    if (notificationId != null) {
      try {
        final supabaseService = ref.read(supabaseServiceProvider);
        await supabaseService.deleteNotification(notificationId);
      } catch (e) {
        // Restore if delete fails
        setState(() {
          _notifications.add(notification);
          _notifications.sort((a, b) => 
            (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        });
      }
    }
  }
}

/// Individual Notification Card Widget
class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _subtitleGray = Color(0xFFB0B0B0);
  static const Color _accentGreen = Color(0xFF4CAF50);

  IconData _getIcon() {
    switch (notification['type']) {
      case 'quote':
        return LucideIcons.tag;
      case 'order':
        return LucideIcons.package;
      case 'message':
        return LucideIcons.messageCircle;
      case 'system':
        return LucideIcons.info;
      default:
        return LucideIcons.bell;
    }
  }

  Color _getIconColor() {
    switch (notification['type']) {
      case 'quote':
        return Colors.orange;
      case 'order':
        return Colors.blue;
      case 'message':
        return _accentGreen;
      case 'system':
        return Colors.purple;
      default:
        return Colors.white;
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['read'] as bool? ?? false;

    return Dismissible(
      key: Key(notification['id']?.toString() ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? _cardBackground : _cardBackground.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? Colors.white.withOpacity(0.05) : _accentGreen.withOpacity(0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getIconColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIcon(), color: _getIconColor(), size: 22),
              ),
              const SizedBox(width: 14),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] as String? ?? 'Notification',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _accentGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['body'] as String? ?? '',
                      style: const TextStyle(color: _subtitleGray, fontSize: 13, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(notification['created_at'] as String?),
                      style: TextStyle(color: _subtitleGray.withOpacity(0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              const Icon(LucideIcons.chevronRight, color: _subtitleGray, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
