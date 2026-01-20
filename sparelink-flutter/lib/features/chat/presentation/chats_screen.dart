import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/sparelink_logo.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import 'chat_detail_panel.dart';
import 'chat_providers.dart';

/// Chats Screen - List of chat conversations
/// Clean dark-mode design with search, avatars, shop names, online status, and message previews
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // Design constants
  static const Color _backgroundColor = Color(0xFF121212);
  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _subtitleGray = Color(0xFFB0B0B0);

  // Real data from Supabase
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;
  
  // Real-time subscription for instant badge updates
  RealtimeChannel? _messageSubscription;

  // Avatar colors for visual variety
  final List<Color> _avatarColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.red,
    Colors.indigo,
    Colors.amber,
    Colors.pink,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _subscribeToMessageUpdates();
  }
  
  /// REAL-TIME LISTENER: Subscribe to message changes for instant badge updates
  /// This triggers UI rebuild immediately when messages are marked as read
  void _subscribeToMessageUpdates() {
    _messageSubscription = Supabase.instance.client
        .channel('chats_screen_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'request_chat_messages',
          callback: (payload) {
            debugPrint('📨 [ChatsScreen] Real-time message update received');
            // Refresh chat list when any message changes (new message, read status change)
            if (mounted) {
              _loadConversations();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            debugPrint('📨 [ChatsScreen] Real-time message update (messages table)');
            if (mounted) {
              _loadConversations();
            }
          },
        )
        .subscribe();
    
    debugPrint('✅ [ChatsScreen] Subscribed to real-time message updates');
  }

  Future<void> _loadConversations() async {
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
          _error = 'Please log in to view chats';
          _isLoading = false;
        });
        return;
      }

      // Load request_chats for mechanic's requests (these are the shop conversations)
      final requestChats = await supabaseService.getMechanicRequestChats(_currentUserId!);
      
      // Also load traditional conversations for backwards compatibility
      final conversations = await supabaseService.getUserConversations(_currentUserId!);
      
      // Combine both - request_chats take priority
      final allChats = <Map<String, dynamic>>[];
      
      // Add request_chats first (primary source) with last message
      for (final chat in requestChats) {
        // Fetch the last message for this chat (including sender info for ticks)
        String? lastMessageText;
        String? lastMessageAt;
        bool lastMessageIsMine = false;
        bool lastMessageIsRead = false;
        
        try {
          final requestId = chat['request_id'] ?? chat['part_requests']?['id'];
          final shopId = chat['shop_id'] ?? chat['shops']?['id'];
          
          if (requestId != null && shopId != null) {
            final lastMsg = await supabaseService.getLastMessageForChat(requestId, shopId);
            if (lastMsg != null) {
              lastMessageText = lastMsg['text'] as String?;
              lastMessageAt = lastMsg['sent_at'] as String?;
              lastMessageIsMine = lastMsg['sender_id'] == _currentUserId;
              lastMessageIsRead = lastMsg['is_read'] as bool? ?? false;
            }
          }
        } catch (e) {
          debugPrint('Error fetching last message: $e');
        }
        
        // Fetch unread message count
        int unreadCount = 0;
        try {
          unreadCount = await supabaseService.getUnreadCountForChat(
            chat['request_id'] ?? chat['part_requests']?['id'], 
            chat['shop_id'] ?? chat['shops']?['id'],
            _currentUserId!,
          );
        } catch (e) {
          debugPrint('Error fetching unread count: $e');
        }
        
        allChats.add({
          'id': chat['id'],
          'type': 'request_chat',
          'shops': chat['shops'],
          'part_requests': chat['part_requests'],
          'status': chat['status'],
          'quote_amount': chat['quote_amount'],
          'delivery_fee': chat['delivery_fee'],
          'created_at': chat['created_at'],
          'updated_at': chat['updated_at'],
          'last_message_text': lastMessageText,
          'last_message_at': lastMessageAt,
          'last_message_is_mine': lastMessageIsMine,
          'last_message_is_read': lastMessageIsRead,
          'request_id': chat['request_id'],
          'shop_id': chat['shop_id'],
          'unread_count': unreadCount,
        });
      }
      
      // Add any traditional conversations not already covered
      for (final conv in conversations) {
        final existsInRequestChats = allChats.any((c) => 
          c['shops']?['id'] == conv['shops']?['id'] && 
          c['part_requests']?['id'] == conv['request_id']);
        
        if (!existsInRequestChats) {
          allChats.add({
            ...conv,
            'type': 'conversation',
          });
        }
      }
      
      // 24-HOUR TTL FILTER: Remove chats with no activity in last 24 hours
      // Only applies to completed/rejected chats - pending and quoted chats stay visible
      final ttlCutoff = DateTime.now().subtract(const Duration(hours: 24));
      final filteredChats = allChats.where((chat) {
        final status = chat['status'] as String?;
        
        // Always show pending and quoted chats
        if (status == 'pending' || status == 'quoted' || status == null) {
          return true;
        }
        
        // For completed/rejected/accepted - check last activity time
        final lastActivityStr = chat['last_message_at'] ?? chat['updated_at'] ?? chat['created_at'];
        if (lastActivityStr == null) return true;
        
        try {
          final lastActivity = DateTime.parse(lastActivityStr as String);
          return lastActivity.isAfter(ttlCutoff);
        } catch (e) {
          return true; // Keep if date parsing fails
        }
      }).toList();
      
      // Sort chats by last_message_at (newest first), falling back to updated_at
      filteredChats.sort((a, b) {
        final aTime = a['last_message_at'] ?? a['updated_at'] ?? a['created_at'];
        final bTime = b['last_message_at'] ?? b['updated_at'] ?? b['created_at'];
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return DateTime.parse(bTime as String).compareTo(DateTime.parse(aTime as String));
      });
      
      setState(() {
        _chats = filteredChats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      setState(() {
        _error = 'Failed to load conversations: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Color _getAvatarColor(int index) {
    return _avatarColors[index % _avatarColors.length];
  }
  
  /// CRITICAL FIX: Mark all messages as read IMMEDIATELY when chat tile is tapped
  /// This clears the unread badge before navigating to the chat
  /// 
  /// ROOT CAUSE FIX: Chats use 'request_chat_messages' table (NOT 'messages' table)
  /// The getUnreadCountForChat now queries request_chat_messages, so we must update that same table
  Future<void> _markChatAsRead(Map<String, dynamic> chat) async {
    if (_currentUserId == null) return;
    
    final requestId = chat['request_id'] ?? chat['part_requests']?['id'];
    final shopId = chat['shop_id'] ?? chat['shops']?['id'];
    
    if (requestId == null || shopId == null) {
      debugPrint('⚠️ [ChatsScreen] Cannot mark as read - missing requestId or shopId');
      return;
    }
    
    try {
      debugPrint('📖 [ChatsScreen] Marking messages as read for request: $requestId, shop: $shopId');
      
      // DIRECT UPDATE to request_chat_messages table
      // This is the SAME table that getUnreadCountForChat queries!
      final result = await Supabase.instance.client
          .from('request_chat_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('request_id', requestId)
          .eq('shop_id', shopId)
          .neq('sender_id', _currentUserId!)
          .eq('is_read', false)
          .select('id');
      
      final updatedCount = (result as List).length;
      debugPrint('✅ [ChatsScreen] Marked $updatedCount messages as read in request_chat_messages table');
      
      // IMMEDIATELY update local state to clear badge (no wait for next DB query)
      if (mounted) {
        setState(() {
          final chatIndex = _chats.indexWhere((c) => 
            c['request_id'] == requestId && (c['shop_id'] ?? c['shops']?['id']) == shopId);
          if (chatIndex != -1) {
            _chats[chatIndex]['unread_count'] = 0;
            debugPrint('✅ [ChatsScreen] Local state updated - badge cleared');
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ [ChatsScreen] Failed to mark messages as read: $e');
      
      // Fallback: Try the old conversations+messages tables
      try {
        final conversationResult = await Supabase.instance.client
            .from('conversations')
            .select('id')
            .eq('request_id', requestId)
            .eq('shop_id', shopId)
            .maybeSingle();
        
        if (conversationResult != null) {
          await Supabase.instance.client
              .from('messages')
              .update({
                'is_read': true,
                'read_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('conversation_id', conversationResult['id'])
              .neq('sender_id', _currentUserId!)
              .eq('is_read', false);
          debugPrint('✅ [ChatsScreen] Fallback: Marked messages as read via conversations table');
        }
        
        // Update local state
        if (mounted) {
          setState(() {
            final chatIndex = _chats.indexWhere((c) => 
              c['request_id'] == requestId && (c['shop_id'] ?? c['shops']?['id']) == shopId);
            if (chatIndex != -1) {
              _chats[chatIndex]['unread_count'] = 0;
            }
          });
        }
      } catch (e2) {
        debugPrint('⚠️ [ChatsScreen] Fallback also failed: $e2');
      }
    }
  }

  String _getLastMessage(Map<String, dynamic> chat) {
    // First check for actual last message text
    final lastMessageText = chat['last_message_text'] as String?;
    if (lastMessageText != null && lastMessageText.isNotEmpty) {
      // Truncate long messages
      if (lastMessageText.length > 40) {
        return '${lastMessageText.substring(0, 40)}...';
      }
      return lastMessageText;
    }
    
    // Fall back to status-based preview for request_chats
    if (chat['type'] == 'request_chat') {
      final status = chat['status'] as String?;
      final quoteAmount = chat['quote_amount'];
      
      if (status == 'quoted' && quoteAmount != null) {
        final priceRands = (quoteAmount as num) / 100;
        return 'Quoted: R${priceRands.toStringAsFixed(2)}';
      } else if (status == 'accepted') {
        return 'Quote accepted ✓';
      } else if (status == 'rejected') {
        return 'Quote declined';
      } else {
        return 'No messages yet';
      }
    }
    
    // For traditional conversations
    final messages = chat['messages'] as List?;
    if (messages != null && messages.isNotEmpty) {
      return messages.last['text'] ?? 'No messages yet';
    }
    return 'No messages yet';
  }

  String _getShopName(Map<String, dynamic> chat) {
    final shop = chat['shops'] as Map<String, dynamic>?;
    return shop?['name'] ?? 'Unknown Shop';
  }
  
  String _getVehicleInfo(Map<String, dynamic> chat) {
    final request = chat['part_requests'] as Map<String, dynamic>?;
    if (request != null) {
      return '${request['vehicle_year']} ${request['vehicle_make']} ${request['vehicle_model']}';
    }
    return '';
  }
  
  String _getPartCategory(Map<String, dynamic> chat) {
    final request = chat['part_requests'] as Map<String, dynamic>?;
    return request?['part_category'] ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageSubscription?.unsubscribe();
    super.dispose();
  }

  // Desktop breakpoint
  static const double _desktopBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _desktopBreakpoint;
    
    if (isDesktop) {
      return _buildDesktopLayout(context);
    }
    return _buildMobileLayout(context);
  }
  
  /// Mobile layout - original single-column view with bottom nav
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Chats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Search bar
            _buildSearchBar(),
            
            // Chat list
            Expanded(
              child: _buildChatList(isDesktop: false),
            ),
          ],
        ),
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
  
  /// Desktop layout - master-detail view with chat list on left, messages on right
  Widget _buildDesktopLayout(BuildContext context) {
    final selectedChat = ref.watch(selectedChatProvider);
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Row(
        children: [
          // Left pane: Chat list (30% width, min 320px)
          Container(
            width: 360,
            decoration: BoxDecoration(
              color: _backgroundColor,
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
            ),
            child: Column(
              children: [
                // Desktop header
                _buildDesktopHeader(),
                
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSearchBar(),
                ),
                
                // Chat list
                Expanded(
                  child: _buildChatList(isDesktop: true),
                ),
              ],
            ),
          ),
          
          // Right pane: Chat detail (70% width)
          Expanded(
            child: selectedChat != null
                ? ChatDetailPanel(
                    key: ValueKey(selectedChat['id']),
                    chatData: selectedChat,
                  )
                : const ChatEmptyState(),
          ),
        ],
      ),
    );
  }
  
  /// Desktop header - simpler, no back button
  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackground,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Chats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Notification icon with hover effect
          _DesktopIconButton(
            icon: LucideIcons.bell,
            onTap: () => context.push('/notifications'),
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
          // New chat icon
          _DesktopIconButton(
            icon: LucideIcons.squarePen,
            onTap: () => context.push('/request-part'),
            tooltip: 'New Request',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button and logo
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    LucideIcons.arrowLeft,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SpareLinkFullLogo(iconSize: 28),
            ],
          ),
          // Notification icon
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: const Icon(
              LucideIcons.bell,
              color: _subtitleGray,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.search, color: _subtitleGray, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search Sechet',
                  hintStyle: TextStyle(color: _subtitleGray),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList({required bool isDesktop}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.circleAlert, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: _subtitleGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.messageCircle, color: _subtitleGray, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a part request to chat with shops',
              style: TextStyle(color: _subtitleGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/camera'),
              icon: const Icon(LucideIcons.camera),
              label: const Text('Request a Part'),
            ),
          ],
        ),
      );
    }

    final selectedChat = ref.watch(selectedChatProvider);

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final shopName = _getShopName(chat);
          final lastMessage = _getLastMessage(chat);
          
          final unreadCount = chat['unread_count'] as int? ?? 0;
          final isSelected = isDesktop && selectedChat?['id'] == chat['id'];
          
          return _ChatCard(
            chat: {
              'id': chat['id'],
              'name': shopName,
              'preview': lastMessage,
              'avatarColor': _getAvatarColor(index),
              'conversation': chat,
              'unread_count': unreadCount,
              'last_message_at': chat['last_message_at'],
              'last_message_is_mine': chat['last_message_is_mine'] ?? false,
              'last_message_is_read': chat['last_message_is_read'] ?? false,
            },
            isSelected: isSelected,
            isDesktop: isDesktop,
            onTap: () async {
              // CRITICAL: Mark messages as read IMMEDIATELY on tap (before navigation)
              // This clears the unread badge instantly
              await _markChatAsRead(chat);
              
              if (isDesktop) {
                // Desktop: Update provider to show chat in right pane (no navigation)
                ref.read(selectedChatProvider.notifier).state = {
                  'id': chat['id'],
                  'name': shopName,
                  'avatarColor': _getAvatarColor(index),
                  'conversation': chat,
                  'type': chat['type'],
                  'request_id': chat['request_id'],
                  'shop_id': chat['shop_id'] ?? chat['shops']?['id'],
                  'shops': chat['shops'],
                  'part_requests': chat['part_requests'],
                  'status': chat['status'],
                  'quote_amount': chat['quote_amount'],
                  'delivery_fee': chat['delivery_fee'],
                };
              } else {
                // Mobile: Navigate to chat screen
                if (mounted) {
                  debugPrint('🚀 [ChatsScreen] Navigating to chat with data: ${chat.keys.toList()}');
                  await context.push('/chat/${chat['id']}', extra: {
                    'id': chat['id'],
                    'name': shopName,
                    'avatarColor': _getAvatarColor(index),
                    'conversation': chat,
                    'type': chat['type'],
                    'request_id': chat['request_id'],
                    'shop_id': chat['shop_id'] ?? chat['shops']?['id'],
                    'shops': chat['shops'],
                    'part_requests': chat['part_requests'],
                    'status': chat['status'],
                    'quote_amount': chat['quote_amount'],
                    'delivery_fee': chat['delivery_fee'],
                  });
                  
                  // CACHE INVALIDATION: Force refresh when returning from chat
                  if (mounted) {
                    _loadConversations();
                  }
                }
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _cardBackground,
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: LucideIcons.grid3x3,
              label: 'Home',
              isActive: false,
              onTap: () => context.go('/'),
            ),
            _buildNavItem(
              icon: LucideIcons.clipboardList,
              label: 'My Requests',
              isActive: false,
              onTap: () => context.push('/my-requests'),
            ),
            _buildNavItem(
              icon: LucideIcons.messageCircle,
              label: 'Chats',
              isActive: true,
              onTap: () {},
            ),
            _buildNavItem(
              icon: LucideIcons.user,
              label: 'Profile',
              isActive: false,
              onTap: () => context.push('/profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.white : _subtitleGray,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : _subtitleGray,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop icon button with hover effect
class _DesktopIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _DesktopIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_DesktopIconButton> createState() => _DesktopIconButtonState();
}

class _DesktopIconButtonState extends State<_DesktopIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isHovered ? Colors.white.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              color: _isHovered ? Colors.white : const Color(0xFFB0B0B0),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chat Card Widget - WhatsApp-style design with desktop hover support
/// Layout: [Avatar] [Name + Message Preview] [Timestamp + Status Ticks]
class _ChatCard extends StatefulWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isDesktop;

  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _subtitleGray = Color(0xFFB0B0B0);
  static const Color _tickGray = Color(0xFF8E8E8E);
  static const Color _tickBlue = Color(0xFF53BDEB);

  const _ChatCard({
    required this.chat,
    required this.onTap,
    this.isSelected = false,
    this.isDesktop = false,
  });

  @override
  State<_ChatCard> createState() => _ChatCardState();
}

class _ChatCardState extends State<_ChatCard> {
  bool _isHovered = false;

  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _subtitleGray = Color(0xFFB0B0B0);
  static const Color _tickGray = Color(0xFF8E8E8E);
  static const Color _tickBlue = Color(0xFF53BDEB);
  static const Color _selectedBackground = Color(0xFF2A3A2A);
  static const Color _hoverBackground = Color(0xFF252525);

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final utcDate = DateTime.parse(timestamp);
      final localDate = utcDate.toLocal();
      final now = DateTime.now();
      final isToday = localDate.year == now.year && 
                      localDate.month == now.month && 
                      localDate.day == now.day;
      final isYesterday = localDate.year == now.year && 
                          localDate.month == now.month && 
                          localDate.day == now.day - 1;
      
      if (isToday) {
        return '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
      } else if (isYesterday) {
        return 'Yesterday';
      } else {
        return '${localDate.day}/${localDate.month}/${localDate.year.toString().substring(2)}';
      }
    } catch (e) {
      return '';
    }
  }

  /// Build message status ticks (WhatsApp style)
  /// - Single grey tick: Sent (message exists)
  /// - Double grey tick: Delivered (is_read = false)
  /// - Double blue tick: Seen (is_read = true)
  Widget _buildStatusTicks() {
    final isFromCurrentUser = widget.chat['last_message_is_mine'] as bool? ?? false;
    final isRead = widget.chat['last_message_is_read'] as bool? ?? false;
    
    // Only show ticks for messages sent by current user
    if (!isFromCurrentUser) {
      return const SizedBox.shrink();
    }
    
    if (isRead) {
      // Double blue ticks - Seen
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.checkCheck, size: 16, color: _tickBlue),
        ],
      );
    } else {
      // Double grey ticks - Delivered/Received
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.checkCheck, size: 16, color: _tickGray),
        ],
      );
    }
  }
  
  Color _getBackgroundColor() {
    if (widget.isSelected) return _selectedBackground;
    if (_isHovered && widget.isDesktop) return _hoverBackground;
    return _cardBackground;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.chat['unread_count'] as int? ?? 0;
    final hasUnread = unreadCount > 0;
    final timestamp = widget.chat['last_message_at'] as String?;
    final preview = widget.chat['preview'] as String? ?? 'No messages yet';
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected 
                ? Border.all(color: AppTheme.accentGreen.withOpacity(0.5), width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Far Left: Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: widget.chat['avatarColor'] as Color,
                child: Text(
                  (widget.chat['name'] as String).isNotEmpty 
                      ? (widget.chat['name'] as String).split(' ').last[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              
              // Middle: Name (top) + Message Preview (bottom)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Name
                    Text(
                      widget.chat['name'] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Message preview with status tick
                    Row(
                      children: [
                        // Status ticks for own messages
                        _buildStatusTicks(),
                        if (widget.chat['last_message_is_mine'] == true)
                          const SizedBox(width: 4),
                        // Preview text
                        Expanded(
                          child: Text(
                            preview,
                            style: TextStyle(
                              color: hasUnread ? Colors.white : _subtitleGray,
                              fontSize: 14,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 10),
              
              // Far Right: Timestamp (top) + Unread Badge (bottom)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Timestamp
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      color: hasUnread ? Colors.green : _subtitleGray,
                      fontSize: 12,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Unread badge or empty space
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20), // Maintain spacing when no badge
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
