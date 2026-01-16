import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/storage_service.dart';

/// Request Chats Screen - Shows all shop responses to a request
/// This is the chat-based flow where shops send quotes and mechanic accepts one
class RequestChatsScreen extends ConsumerStatefulWidget {
  final String requestId;
  
  const RequestChatsScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestChatsScreen> createState() => _RequestChatsScreenState();
}

class _RequestChatsScreenState extends ConsumerState<RequestChatsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _request;
  List<Map<String, dynamic>> _requestItems = [];
  List<Map<String, dynamic>> _shopChats = [];
  StreamSubscription? _chatsSubscription;

  @override
  void initState() {
    super.initState();
    _loadRequestData();
    _subscribeToChats();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRequestData() async {
    setState(() => _isLoading = true);
    try {
      // Load request details
      final requestResponse = await Supabase.instance.client
          .from('part_requests')
          .select()
          .eq('id', widget.requestId)
          .single();
      
      // Load request items
      final itemsResponse = await Supabase.instance.client
          .from('request_items')
          .select()
          .eq('request_id', widget.requestId);
      
      // Load shop chats with shop details
      final chatsResponse = await Supabase.instance.client
          .from('request_chats')
          .select('*, shops:shop_id(id, name, phone, suburb, rating)')
          .eq('request_id', widget.requestId)
          .order('created_at');
      
      setState(() {
        _request = requestResponse;
        _requestItems = List<Map<String, dynamic>>.from(itemsResponse);
        _shopChats = List<Map<String, dynamic>>.from(chatsResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load request: $e');
    }
  }

  void _subscribeToChats() {
    _chatsSubscription = Supabase.instance.client
        .from('request_chats')
        .stream(primaryKey: ['id'])
        .eq('request_id', widget.requestId)
        .listen((data) {
          _loadRequestData(); // Reload when chats update
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Shop Responses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Request Summary Card
        _buildRequestSummary(),
        
        // Shop Chats List
        Expanded(
          child: _shopChats.isEmpty
              ? _buildWaitingForShops()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shopChats.length,
                  itemBuilder: (context, index) => _buildShopChatCard(_shopChats[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildRequestSummary() {
    if (_request == null) return const SizedBox();
    
    final vehicleInfo = '${_request!['vehicle_year']} ${_request!['vehicle_make']} ${_request!['vehicle_model']}';
    final partsCount = _requestItems.length;
    final partsList = _requestItems.map((p) => '${p['part_name']} x${p['quantity']}').join(', ');
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.car, color: AppTheme.accentGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicleInfo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('$partsCount part${partsCount > 1 ? 's' : ''} requested', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ],
                ),
              ),
              _buildStatusBadge(_request!['status'] ?? 'pending'),
            ],
          ),
          const SizedBox(height: 12),
          Text(partsList, style: TextStyle(color: Colors.grey[300], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Waiting';
        break;
      case 'quoted':
        color = Colors.blue;
        label = 'Quotes In';
        break;
      case 'accepted':
        color = AppTheme.accentGreen;
        label = 'Accepted';
        break;
      case 'completed':
        color = Colors.green;
        label = 'Completed';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildWaitingForShops() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.clock, color: Colors.orange, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            'Waiting for shop responses...',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Shops in your area have been notified.\nYou\'ll see their quotes here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildShopChatCard(Map<String, dynamic> chat) {
    final shop = chat['shops'] as Map<String, dynamic>?;
    final shopName = shop?['name'] ?? 'Unknown Shop';
    final shopSuburb = shop?['suburb'] ?? '';
    final chatStatus = chat['status'] ?? 'pending';
    final quote = chat['quote_amount'];
    final deliveryFee = chat['delivery_fee'];
    final deliveryTime = chat['delivery_time'];
    
    return GestureDetector(
      onTap: () => context.push('/chat/${chat['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: chatStatus == 'accepted' 
                ? AppTheme.accentGreen 
                : chatStatus == 'quoted' 
                    ? Colors.blue.withOpacity(0.5) 
                    : Colors.grey[800]!,
            width: chatStatus == 'accepted' ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Shop Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.store, color: Colors.grey, size: 24),
                ),
                const SizedBox(width: 12),
                
                // Shop Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shopName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(LucideIcons.mapPin, color: Colors.grey[500], size: 12),
                          const SizedBox(width: 4),
                          Text(shopSuburb, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status/Quote
                _buildChatStatus(chatStatus, quote),
              ],
            ),
            
            // Quote Details (if quoted)
            if (chatStatus == 'quoted' && quote != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Convert cents to rands for display
                              Text('Quote: R${(quote / 100).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              if (deliveryFee != null)
                                Text('+ R${(deliveryFee / 100).toStringAsFixed(2)} delivery', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                              if (deliveryTime != null)
                                Text(deliveryTime, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Accept and Reject buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectQuote(chat),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _acceptQuote(chat),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentGreen,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            // Accepted Badge
            if (chatStatus == 'accepted') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.circleCheck, color: AppTheme.accentGreen, size: 20),
                    const SizedBox(width: 8),
                    const Text('Quote Accepted - Tap to chat', style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            
            // Tap to view
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Tap to view conversation', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, color: Colors.grey[500], size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatStatus(String status, dynamic quote) {
    switch (status) {
      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Pending', style: TextStyle(color: Colors.grey, fontSize: 12)),
        );
      case 'quoted':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.tag, color: Colors.blue, size: 14),
              SizedBox(width: 4),
              Text('Quoted', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      case 'accepted':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.check, color: AppTheme.accentGreen, size: 14),
              SizedBox(width: 4),
              Text('Accepted', style: TextStyle(color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      case 'rejected':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Declined', style: TextStyle(color: Colors.red, fontSize: 12)),
        );
      default:
        return const SizedBox();
    }
  }

  Future<void> _acceptQuote(Map<String, dynamic> chat) async {
    try {
      // Update this chat to accepted
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'accepted'})
          .eq('id', chat['id']);
      
      // Reject all other chats for this request
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'rejected'})
          .eq('request_id', widget.requestId)
          .neq('id', chat['id']);
      
      // Update request status
      await Supabase.instance.client
          .from('part_requests')
          .update({'status': 'accepted', 'accepted_shop_id': chat['shop_id']})
          .eq('id', widget.requestId);
      
      // Navigate to chat
      if (mounted) {
        context.push('/chat/${chat['id']}');
      }
    } catch (e) {
      _showError('Failed to accept quote: $e');
    }
  }

  Future<void> _rejectQuote(Map<String, dynamic> chat) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Reject Quote', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reject this quote from ${chat['shops']?['name'] ?? 'this shop'}?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Update this chat to rejected
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'rejected'})
          .eq('id', chat['id']);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Reload data
      _loadRequestData();
    } catch (e) {
      _showError('Failed to reject quote: $e');
    }
  }
}
