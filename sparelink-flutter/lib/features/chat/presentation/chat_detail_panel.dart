import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import 'chat_providers.dart';

/// Chat Detail Panel for desktop master-detail view
/// This is an embedded version of IndividualChatScreen without navigation chrome
class ChatDetailPanel extends ConsumerStatefulWidget {
  final Map<String, dynamic> chatData;
  
  const ChatDetailPanel({
    super.key,
    required this.chatData,
  });

  @override
  ConsumerState<ChatDetailPanel> createState() => _ChatDetailPanelState();
}

class _ChatDetailPanelState extends ConsumerState<ChatDetailPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  // Design constants - UX-01 FIX: Use AppTheme colors for consistency
  static const Color _backgroundColor = Color(0xFF000000);  // AppTheme.primaryBlack
  static const Color _cardBackground = Color(0xFF1A1A1A);   // AppTheme.darkGray
  static const Color _userMessageBackground = Color(0xFF2A2A2A); // AppTheme.mediumGray
  static const Color _subtitleGray = Color(0xFF888888);     // AppTheme.lightGray
  static const Color _timestampGray = Color(0xFF666666);    // AppTheme.textHint
  static const Color _hoverColor = Color(0xFF2A2A2A);       // AppTheme.mediumGray

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  String? _currentUserId;
  RealtimeChannel? _messageSubscription;
  int? _hoveredMessageIndex;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }
  
  @override
  void didUpdateWidget(ChatDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload messages when chat changes
    if (oldWidget.chatData['id'] != widget.chatData['id']) {
      _messageSubscription?.unsubscribe();
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storageService = ref.read(storageServiceProvider);
      _currentUserId = await storageService.getUserId();
      
      final requestId = widget.chatData['request_id'] ?? widget.chatData['part_requests']?['id'];
      final shopId = widget.chatData['shop_id'] ?? widget.chatData['shops']?['id'];
      
      if (requestId == null || shopId == null) {
        setState(() {
          _error = 'Invalid chat data';
          _isLoading = false;
        });
        return;
      }

      // Load messages from request_chat_messages
      final messages = await Supabase.instance.client
          .from('request_chat_messages')
          .select('*')
          .eq('request_id', requestId)
          .eq('shop_id', shopId)
          .order('sent_at', ascending: true);
      
      setState(() {
        _messages = List<Map<String, dynamic>>.from(messages);
        _isLoading = false;
      });
      
      // Subscribe to real-time updates
      _subscribeToMessages(requestId, shopId);
      
      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      
      // Mark messages as read
      _markMessagesAsRead(requestId, shopId);
    } catch (e) {
      setState(() {
        _error = 'Failed to load messages: $e';
        _isLoading = false;
      });
    }
  }
  
  void _subscribeToMessages(String requestId, String shopId) {
    _messageSubscription = Supabase.instance.client
        .channel('chat_detail_$requestId\_$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'request_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: requestId,
          ),
          callback: (payload) {
            final newMessage = payload.newRecord;
            if (newMessage['shop_id'] == shopId) {
              setState(() {
                _messages.add(newMessage);
              });
              _scrollToBottom();
              
              // Mark as read if from other user
              if (newMessage['sender_id'] != _currentUserId) {
                _markMessagesAsRead(requestId, shopId);
              }
            }
          },
        )
        .subscribe();
  }
  
  Future<void> _markMessagesAsRead(String requestId, String shopId) async {
    if (_currentUserId == null) return;
    
    try {
      await Supabase.instance.client
          .from('request_chat_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('request_id', requestId)
          .eq('shop_id', shopId)
          .neq('sender_id', _currentUserId!)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    
    setState(() => _isSending = true);
    
    try {
      final requestId = widget.chatData['request_id'] ?? widget.chatData['part_requests']?['id'];
      final shopId = widget.chatData['shop_id'] ?? widget.chatData['shops']?['id'];
      
      await Supabase.instance.client.from('request_chat_messages').insert({
        'request_id': requestId,
        'shop_id': shopId,
        'sender_id': _currentUserId,
        'content': text,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
        'is_read': false,
      });
      
      _messageController.clear();
      _messageFocusNode.requestFocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }
  
  // Handle Ctrl+Enter to send
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          HardwareKeyboard.instance.isControlPressed) {
        _sendMessage();
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messageSubscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.chatData['shops'] as Map<String, dynamic>?;
    final request = widget.chatData['part_requests'] as Map<String, dynamic>?;
    final shopName = shop?['name'] ?? 'Unknown Shop';
    final vehicleInfo = request != null 
        ? '${request['vehicle_year']} ${request['vehicle_make']} ${request['vehicle_model']}'
        : '';
    
    return Container(
      color: _backgroundColor,
      child: Column(
        children: [
          // Header
          _buildHeader(shopName, vehicleInfo),
          
          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.1)),
          
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _buildMessageList(),
          ),
          
          // Input
          _buildMessageInput(),
        ],
      ),
    );
  }
  
  Widget _buildHeader(String shopName, String vehicleInfo) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _cardBackground,
      child: Row(
        children: [
          // Shop avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.accentGreen,
            child: Text(
              shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
          // Shop info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (vehicleInfo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    vehicleInfo,
                    style: const TextStyle(color: _subtitleGray, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          // Quote status badge
          _buildStatusBadge(),
        ],
      ),
    );
  }
  
  Widget _buildStatusBadge() {
    final status = widget.chatData['status'] as String?;
    final quoteAmount = widget.chatData['quote_amount'];
    
    if (status == 'quoted' && quoteAmount != null) {
      final priceRands = (quoteAmount as num) / 100;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentGreen),
        ),
        child: Text(
          'R${priceRands.toStringAsFixed(2)}',
          style: const TextStyle(
            color: AppTheme.accentGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
  
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.messageSquare, size: 64, color: _subtitleGray.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(color: _subtitleGray, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start the conversation!',
              style: TextStyle(color: _timestampGray, fontSize: 14),
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
        final isMe = message['sender_id'] == _currentUserId;
        
        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredMessageIndex = index),
          onExit: (_) => setState(() => _hoveredMessageIndex = null),
          child: _buildMessageBubble(message, isMe, index),
        );
      },
    );
  }
  
  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe, int index) {
    final text = message['content'] as String? ?? '';
    final sentAt = message['sent_at'] as String?;
    final isRead = message['is_read'] as bool? ?? false;
    final isHovered = _hoveredMessageIndex == index;
    
    String timeString = '';
    if (sentAt != null) {
      final dateTime = DateTime.parse(sentAt).toLocal();
      timeString = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 40), // Space for avatar
          
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe 
                    ? (isHovered ? AppTheme.accentGreen.withOpacity(0.9) : AppTheme.accentGreen)
                    : (isHovered ? _hoverColor : _userMessageBackground),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.black : Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeString,
                        style: TextStyle(
                          color: isMe ? Colors.black54 : _timestampGray,
                          fontSize: 11,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? LucideIcons.checkCheck : LucideIcons.check,
                          size: 14,
                          color: isRead ? Colors.black87 : Colors.black54,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (isMe) const SizedBox(width: 40),
        ],
      ),
    );
  }
  
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _cardBackground,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: _handleKeyEvent,
        child: Row(
          children: [
            // Attachment button
            IconButton(
              onPressed: () {},
              icon: const Icon(LucideIcons.paperclip, color: _subtitleGray),
              tooltip: 'Attach file',
            ),
            
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type a message... (Ctrl+Enter to send)',
                    hintStyle: TextStyle(color: _subtitleGray),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Send button
            Material(
              color: AppTheme.accentGreen,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _isSending ? null : _sendMessage,
                borderRadius: BorderRadius.circular(24),
                hoverColor: AppTheme.accentGreen.withOpacity(0.8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(LucideIcons.send, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state for when no chat is selected
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.messageSquare,
                size: 64,
                color: AppTheme.accentGreen.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select a conversation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a chat from the list to start messaging',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
