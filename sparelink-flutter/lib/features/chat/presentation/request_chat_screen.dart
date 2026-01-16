import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/storage_service.dart';

/// Individual Chat Screen for request negotiation
/// Has structured forms until delivery is confirmed, then becomes free chat
class RequestChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  
  const RequestChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<RequestChatScreen> createState() => _RequestChatScreenState();
}

class _RequestChatScreenState extends ConsumerState<RequestChatScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _chat;
  Map<String, dynamic>? _request;
  Map<String, dynamic>? _shop;
  List<Map<String, dynamic>> _messages = [];
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription? _messagesSubscription;
  String? _currentUserId;
  bool _isMechanic = true;

  @override
  void initState() {
    super.initState();
    _loadChatData();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadChatData() async {
    setState(() => _isLoading = true);
    try {
      final storageService = ref.read(storageServiceProvider);
      _currentUserId = await storageService.getUserId();
      final userRole = await storageService.getUserRole();
      _isMechanic = userRole == 'mechanic';
      
      // Load chat with shop and request details
      final chatResponse = await Supabase.instance.client
          .from('request_chats')
          .select('*, shops:shop_id(*), part_requests:request_id(*)')
          .eq('id', widget.chatId)
          .single();
      
      // Load messages
      final messagesResponse = await Supabase.instance.client
          .from('chat_messages')
          .select()
          .eq('chat_id', widget.chatId)
          .order('created_at');
      
      setState(() {
        _chat = chatResponse;
        _shop = chatResponse['shops'];
        _request = chatResponse['part_requests'];
        _messages = List<Map<String, dynamic>>.from(messagesResponse);
        _isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load chat: $e');
    }
  }

  void _subscribeToMessages() {
    _messagesSubscription = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('created_at')
        .listen((data) {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(data);
          });
          _scrollToBottom();
        });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
          : Column(
              children: [
                Expanded(child: _buildMessagesList()),
                _buildInputArea(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final shopName = _shop?['name'] ?? 'Shop';
    final chatStatus = _chat?['status'] ?? 'pending';
    
    return AppBar(
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.store, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                Text(_getStatusText(chatStatus), style: TextStyle(color: _getStatusColor(chatStatus), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Awaiting response';
      case 'quoted': return 'Quote received';
      case 'accepted': return 'Quote accepted';
      case 'completed': return 'Completed';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'quoted': return Colors.blue;
      case 'accepted': return AppTheme.accentGreen;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return _buildEmptyChat();
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.messageCircle, color: Colors.grey[700], size: 48),
          const SizedBox(height: 16),
          Text(
            _isMechanic 
                ? 'Waiting for shop to respond...'
                : 'Send a quote or message to start',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['sender_id'] == _currentUserId;
    final messageType = message['message_type'] ?? 'text';
    final content = message['content'] ?? '';
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: messageType == 'quote'
            ? _buildQuoteMessage(message, isMe)
            : _buildTextMessage(content, isMe),
      ),
    );
  }

  Widget _buildTextMessage(String content, bool isMe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.accentGreen : const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomRight: isMe ? const Radius.circular(4) : null,
          bottomLeft: !isMe ? const Radius.circular(4) : null,
        ),
      ),
      child: Text(content, style: const TextStyle(color: Colors.white, fontSize: 15)),
    );
  }

  Widget _buildQuoteMessage(Map<String, dynamic> message, bool isMe) {
    final data = message['data'] as Map<String, dynamic>? ?? {};
    final amount = (data['amount'] ?? 0).toDouble();
    final partPrice = (data['part_price'] ?? amount).toDouble();
    final deliveryFee = (data['delivery_fee'] ?? 140.0).toDouble();
    final deliveryTime = data['delivery_time'] ?? '';
    final notes = data['notes'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.tag, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text('Price Quote', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          // Price breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Part Price:', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              Text('R ${partPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Fee:', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              Text('R ${deliveryFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
          const Divider(color: Colors.grey, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('R ${amount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.accentGreen, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          if (deliveryTime.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(LucideIcons.clock, color: Colors.grey[500], size: 14),
                const SizedBox(width: 4),
                Text('Delivery: $deliveryTime', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes, style: TextStyle(color: Colors.grey[300], fontSize: 13)),
          ],
          if (_isMechanic && _chat?['status'] == 'quoted') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectQuote(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptQuote(),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final chatStatus = _chat?['status'] ?? 'pending';
    final isCompleted = chatStatus == 'completed';
    
    // Show different input based on status and role
    if (!_isMechanic && chatStatus == 'pending') {
      return _buildShopQuoteForm();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: isCompleted ? 'Type a message...' : 'Send a message...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF2D2D2D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppTheme.accentGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopQuoteForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Respond to this request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // First row: Not Available & Ask Questions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showNotAvailableDialog(),
                  icon: const Icon(LucideIcons.x, size: 18),
                  label: const Text('Not Available', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAskQuestionDialog(),
                  icon: const Icon(LucideIcons.messageCircleQuestion, size: 18),
                  label: const Text('Ask Question', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Second row: Send Quote (full width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showQuoteDialog(),
              icon: const Icon(LucideIcons.tag),
              label: const Text('Send Price Quote'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAskQuestionDialog() {
    final questionController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ask the Mechanic', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Request more details before sending a quote', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 20),
            TextField(
              controller: questionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Is it the front or rear part? What year model exactly?',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF2D2D2D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final question = questionController.text.trim();
                  if (question.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a question')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _sendQuestion(question);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Send Question', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _sendQuestion(String question) async {
    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'message_type': 'text',
        'content': '❓ $question',
      });
      _loadChatData();
    } catch (e) {
      _showError('Failed to send question: $e');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'message_type': 'text',
        'content': content,
      });
      
      _messageController.clear();
    } catch (e) {
      _showError('Failed to send message: $e');
    }
  }

  void _showQuoteDialog() {
    final priceController = TextEditingController();
    final notesController = TextEditingController();
    String deliveryTime = 'Same day';
    double partPrice = 0;
    const double deliveryFee = 140.0; // Fixed delivery fee of R140
    double totalPrice = 0;
    
    void updateTotals(StateSetter setModalState) {
      partPrice = double.tryParse(priceController.text) ?? 0;
      totalPrice = partPrice + deliveryFee;
      setModalState(() {});
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send Price Quote', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('15% platform fee will be added automatically', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 20),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => updateTotals(setModalState),
                decoration: InputDecoration(
                  labelText: 'Part Price (R) *',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixText: 'R ',
                  prefixStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: const Color(0xFF2D2D2D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              // Fixed delivery fee notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800]!.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.truck, color: Colors.grey[400], size: 18),
                    const SizedBox(width: 10),
                    Text('Delivery Fee: R140 (fixed)', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: deliveryTime,
                dropdownColor: const Color(0xFF2D2D2D),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Delivery Time',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF2D2D2D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: ['Same day', '1-2 days', '3-5 days', '1 week+'].map((t) => 
                  DropdownMenuItem(value: t, child: Text(t))
                ).toList(),
                onChanged: (v) => setModalState(() => deliveryTime = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF2D2D2D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              // Price Summary
              if (partPrice > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Part Price:', style: TextStyle(color: Colors.grey[400])),
                          Text('R ${partPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Delivery Fee (fixed):', style: TextStyle(color: Colors.grey[400])),
                          const Text('R 140.00', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      const Divider(color: Colors.grey, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total to Mechanic:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('R ${totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (partPrice <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid price')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _sendQuote(
                      amount: totalPrice,
                      partPrice: partPrice,
                      deliveryFee: deliveryFee,
                      deliveryTime: deliveryTime,
                      notes: notesController.text,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    partPrice > 0 ? 'Send Quote (R ${totalPrice.toStringAsFixed(2)})' : 'Send Quote',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendQuote({
    required double amount,
    required double partPrice,
    required double deliveryFee,
    required String deliveryTime,
    required String notes,
  }) async {
    try {
      // Send quote message
      await Supabase.instance.client.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'message_type': 'quote',
        'content': 'Price Quote: R${amount.toStringAsFixed(2)}',
        'data': {
          'amount': amount,
          'part_price': partPrice,
          'delivery_fee': deliveryFee,
          'delivery_time': deliveryTime,
          'notes': notes,
        },
      });
      
      // Update chat status
      await Supabase.instance.client
          .from('request_chats')
          .update({
            'status': 'quoted',
            'quote_amount': amount,
            'delivery_fee': deliveryFee,
            'delivery_time': deliveryTime,
          })
          .eq('id', widget.chatId);
      
      _loadChatData();
    } catch (e) {
      _showError('Failed to send quote: $e');
    }
  }

  void _showNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Part Not Available?', style: TextStyle(color: Colors.white)),
        content: const Text('This will notify the mechanic that you cannot fulfill this request.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markNotAvailable();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _markNotAvailable() async {
    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'message_type': 'text',
        'content': 'Sorry, this part is not available at our shop.',
      });
      
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'rejected'})
          .eq('id', widget.chatId);
      
      if (mounted) context.pop();
    } catch (e) {
      _showError('Failed to update: $e');
    }
  }

  Future<void> _acceptQuote() async {
    try {
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'accepted'})
          .eq('id', widget.chatId);
      
      // Reject other chats
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'rejected'})
          .eq('request_id', _chat!['request_id'])
          .neq('id', widget.chatId);
      
      await Supabase.instance.client
          .from('part_requests')
          .update({'status': 'accepted', 'accepted_shop_id': _chat!['shop_id']})
          .eq('id', _chat!['request_id']);
      
      await Supabase.instance.client.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'message_type': 'text',
        'content': '✅ Quote accepted! Let\'s arrange delivery.',
      });
      
      _loadChatData();
    } catch (e) {
      _showError('Failed to accept: $e');
    }
  }

  Future<void> _rejectQuote() async {
    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'message_type': 'text',
        'content': 'Thanks, but I\'ll pass on this quote.',
      });
      
      _loadChatData();
    } catch (e) {
      _showError('Failed: $e');
    }
  }
}
