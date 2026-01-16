import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/sparelink_logo.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/storage_service.dart';

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
      
      // Add request_chats first (primary source)
      for (final chat in requestChats) {
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
          'messages': [], // Will load on demand
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
      
      setState(() {
        _chats = allChats;
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

  String _getLastMessage(Map<String, dynamic> chat) {
    // For request_chats, show status-based preview
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
        return 'Awaiting quote...';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: _buildChatList(),
            ),
          ],
        ),
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavBar(),
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

  Widget _buildChatList() {
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

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final shopName = _getShopName(chat);
          final lastMessage = _getLastMessage(chat);
          
          return _ChatCard(
            chat: {
              'id': chat['id'],
              'name': shopName,
              'status': 'Online',
              'preview': lastMessage,
              'avatarColor': _getAvatarColor(index),
              'conversation': chat, // Pass full conversation data
            },
            onTap: () {
              context.push('/chat/${chat['id']}', extra: {
                'id': chat['id'],
                'name': shopName,
                'status': 'Online',
                'avatarColor': _getAvatarColor(index),
                'conversation': chat,
              });
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

/// Chat Card Widget - matches reference design exactly
class _ChatCard extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;

  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _subtitleGray = Color(0xFFB0B0B0);

  const _ChatCard({
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: chat['avatarColor'] as Color,
              child: Text(
                (chat['name'] as String).split(' ').last[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((chat['status'] as String).isNotEmpty)
                    Text(
                      chat['status'] as String,
                      style: const TextStyle(
                        color: _subtitleGray,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            
            // Message preview
            Expanded(
              child: Text(
                chat['preview'] as String,
                style: const TextStyle(
                  color: _subtitleGray,
                  fontSize: 14,
                ),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
