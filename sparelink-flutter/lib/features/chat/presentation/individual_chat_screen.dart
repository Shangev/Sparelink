import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/storage_service.dart';

/// Individual Chat Screen - Conversation with a shop
/// Clean dark-mode design with message bubbles, timestamps, and input field
class IndividualChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final Map<String, dynamic>? chatData;

  const IndividualChatScreen({
    super.key,
    required this.chatId,
    this.chatData,
  });

  @override
  ConsumerState<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends ConsumerState<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Design constants
  static const Color _backgroundColor = Color(0xFF121212);
  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _userMessageBackground = Color(0xFF333333);
  static const Color _subtitleGray = Color(0xFFB0B0B0);
  static const Color _timestampGray = Color(0xFF808080);

  // Real messages from Supabase
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  String? _currentUserId;
  RealtimeChannel? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
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
          _error = 'Please log in to view messages';
          _isLoading = false;
        });
        return;
      }

      final messages = await supabaseService.getMessages(widget.chatId);
      
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Subscribe to new messages
      _subscribeToMessages();
      
      // Scroll to bottom after loading
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = 'Failed to load messages: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _subscribeToMessages() {
    final supabaseService = ref.read(supabaseServiceProvider);
    _messageSubscription = supabaseService.subscribeToMessages(
      widget.chatId,
      (newMessage) {
        // Only add if not already in list (avoid duplicates)
        if (!_messages.any((m) => m['id'] == newMessage['id'])) {
          setState(() {
            _messages.add(newMessage);
          });
          _scrollToBottom();
        }
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;
    
    final messageText = _messageController.text.trim();
    _messageController.clear();
    
    setState(() => _isSending = true);
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      final newMessage = await supabaseService.sendMessage(
        conversationId: widget.chatId,
        senderId: _currentUserId!,
        text: messageText,
      );
      
      // Add to local list immediately for responsiveness
      setState(() {
        if (!_messages.any((m) => m['id'] == newMessage['id'])) {
          _messages.add(newMessage);
        }
      });
      
      _scrollToBottom();
    } catch (e) {
      // Show error and restore message to input
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        _messageController.text = messageText;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      
      if (isToday) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  bool _isCurrentUser(Map<String, dynamic> message) {
    return message['sender_id'] == _currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final shopName = widget.chatData?['name'] as String? ?? 'Shop';
    final avatarColor = widget.chatData?['avatarColor'] as Color? ?? Colors.blue;
    final status = widget.chatData?['status'] as String? ?? 'Online';

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with shop info
            _buildHeader(shopName, avatarColor, status),
            
            // Offer/Quote card at top (if available)
            if (widget.chatData?['type'] == 'request_chat')
              _buildOfferCard(),
            
            // Messages list
            Expanded(
              child: _buildMessagesList(),
            ),
            
            // Input field
            _buildInputField(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOfferCard() {
    final chatData = widget.chatData!;
    final quoteAmount = chatData['quote_amount'];
    final deliveryFee = chatData['delivery_fee'];
    final chatStatus = chatData['status'] as String? ?? 'pending';
    final shop = chatData['shops'] as Map<String, dynamic>?;
    final request = chatData['part_requests'] as Map<String, dynamic>?;
    
    // Format price
    String formatPrice(dynamic cents) {
      if (cents == null) return '—';
      final rands = (cents as num) / 100;
      return 'R ${rands.toStringAsFixed(2)}';
    }
    
    // Calculate total
    final total = (quoteAmount ?? 0) + (deliveryFee ?? 0);
    
    // Status colors
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (chatStatus) {
      case 'quoted':
        statusColor = Colors.blue;
        statusText = 'Quote Received';
        statusIcon = LucideIcons.tag;
        break;
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'Accepted';
        statusIcon = LucideIcons.check;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Declined';
        statusIcon = LucideIcons.x;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Awaiting Quote';
        statusIcon = LucideIcons.clock;
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge and shop name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (shop != null)
                Text(
                  shop['name'] ?? 'Shop',
                  style: const TextStyle(color: _subtitleGray, fontSize: 12),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Vehicle info
          if (request != null) ...[
            Text(
              '${request['vehicle_year']} ${request['vehicle_make']} ${request['vehicle_model']}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              request['part_category'] ?? 'Part Request',
              style: const TextStyle(color: _subtitleGray, fontSize: 14),
            ),
          ],
          
          // Quote details (only if quoted)
          if (chatStatus == 'quoted' || chatStatus == 'accepted') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Part Price:', style: TextStyle(color: _subtitleGray, fontSize: 14)),
                      Text(formatPrice(quoteAmount), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery:', style: TextStyle(color: _subtitleGray, fontSize: 14)),
                      Text(formatPrice(deliveryFee), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  const Divider(color: Color(0xFF3A3A3A), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(formatPrice(total), style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          // Accept button (only for quoted status)
          if (chatStatus == 'quoted') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptQuote(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Accept Quote', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Future<void> _acceptQuote() async {
    final chatData = widget.chatData;
    if (chatData == null) return;
    
    try {
      // Get the request_chat ID and update its status
      final requestChatId = chatData['id'];
      final requestId = chatData['part_requests']?['id'];
      final shopId = chatData['shops']?['id'];
      
      // Update request_chats status to accepted
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'accepted'})
          .eq('id', requestChatId);
      
      // Reject other chats for same request
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'rejected'})
          .eq('request_id', requestId)
          .neq('id', requestChatId);
      
      // Update part_request status
      await Supabase.instance.client
          .from('part_requests')
          .update({'status': 'accepted', 'accepted_shop_id': shopId})
          .eq('id', requestId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote accepted! The shop will prepare your order.'), backgroundColor: Colors.green),
        );
        // Refresh the screen
        setState(() {
          widget.chatData?['status'] = 'accepted';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept quote: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildHeader(String shopName, Color avatarColor, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _backgroundColor,
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                LucideIcons.arrowLeft,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarColor,
            child: Text(
              shopName.split(' ').last[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (status.isNotEmpty)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: const TextStyle(
                          color: _subtitleGray,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // More options
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('More options coming soon')),
              );
            },
            child: const Icon(
              LucideIcons.ellipsisVertical,
              color: _subtitleGray,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
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
              onPressed: _loadMessages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.messageCircle, color: _subtitleGray, size: 48),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(color: _subtitleGray, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = _isCurrentUser(message);
        
        return _MessageBubble(
          text: message['text'] as String? ?? '',
          time: _formatTime(message['sent_at'] as String?),
          isUser: isUser,
        );
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _backgroundColor,
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _cardBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: _subtitleGray),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Send button
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey : Colors.white,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      LucideIcons.send,
                      color: Colors.black,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message Bubble Widget
class _MessageBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isUser;

  static const Color _userMessageBackground = Color(0xFF333333);
  static const Color _shopMessageBackground = Color(0xFF1E1E1E);
  static const Color _timestampGray = Color(0xFF808080);

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? _userMessageBackground : _shopMessageBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                color: _timestampGray,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
