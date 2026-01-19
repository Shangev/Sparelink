import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/marketplace.dart';
import '../../../shared/services/supabase_service.dart';

/// Request Detail Screen
/// Shows full details of a request including accepted offer, shop info, and order status
class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  PartRequest? _request;
  Map<String, dynamic>? _acceptedOffer;
  Map<String, dynamic>? _shop;
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  Future<void> _loadRequestDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Load request
      final requestData = await supabaseService.getRequest(widget.requestId);
      if (requestData != null) {
        _request = PartRequest.fromJson(requestData);
      }
      
      // Load accepted offer (if any)
      final offers = await supabaseService.getOffersForRequest(widget.requestId);
      final accepted = offers.where((o) => o['status'] == 'accepted').toList();
      if (accepted.isNotEmpty) {
        _acceptedOffer = accepted.first;
        
        // Load shop details
        if (_acceptedOffer!['shop_id'] != null) {
          _shop = await supabaseService.getShop(_acceptedOffer!['shop_id']);
        }
      }
      
      // Load order (if any)
      final orders = await supabaseService.getOrdersForRequest(widget.requestId);
      if (orders.isNotEmpty) {
        _order = orders.first;
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load request details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Request #${widget.requestId.substring(0, 8).toUpperCase()}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
            onPressed: _loadRequestDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? _buildErrorState()
              : _request == null
                  ? _buildNotFoundState()
                  : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.circleAlert, size: 48, color: Colors.red.withOpacity(0.7)),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadRequestDetails, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.fileQuestion, size: 48, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('Request not found', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          Text('This request may have been deleted', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadRequestDetails,
      color: AppTheme.accentGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            _buildStatusBanner(),
            const SizedBox(height: 20),
            
            // Part Image
            if (_request!.imageUrl != null) ...[
              _buildPartImage(),
              const SizedBox(height: 20),
            ],
            
            // Vehicle & Part Info
            _buildInfoCard(
              title: 'Request Details',
              icon: LucideIcons.clipboardList,
              children: [
                _buildInfoRow('Part', _request!.partName ?? 'Unknown'),
                _buildInfoRow('Vehicle', _request!.vehicleDisplay),
                _buildInfoRow('Submitted', _request!.timeAgo),
                if (_request!.description != null && _request!.description!.isNotEmpty)
                  _buildInfoRow('Notes', _request!.description!),
              ],
            ),
            const SizedBox(height: 16),
            
            // Accepted Offer Details
            if (_acceptedOffer != null) ...[
              _buildInfoCard(
                title: 'Accepted Quote',
                icon: LucideIcons.badgeCheck,
                accentColor: AppTheme.accentGreen,
                children: [
                  _buildInfoRow('Price', 'R${_acceptedOffer!['price']?.toString() ?? '0'}'),
                  if (_acceptedOffer!['condition'] != null)
                    _buildInfoRow('Condition', _acceptedOffer!['condition']),
                  if (_acceptedOffer!['warranty'] != null)
                    _buildInfoRow('Warranty', _acceptedOffer!['warranty']),
                  if (_acceptedOffer!['delivery_time'] != null)
                    _buildInfoRow('Delivery', _acceptedOffer!['delivery_time']),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Shop Info
            if (_shop != null) ...[
              _buildShopCard(),
              const SizedBox(height: 16),
            ],
            
            // Order Status
            if (_order != null) ...[
              _buildInfoCard(
                title: 'Order Status',
                icon: LucideIcons.truck,
                accentColor: Colors.blue,
                children: [
                  _buildInfoRow('Order ID', '#${(_order!['id'] as String).substring(0, 8).toUpperCase()}'),
                  _buildInfoRow('Status', _order!['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
                  if (_order!['tracking_number'] != null)
                    _buildInfoRow('Tracking', _order!['tracking_number']),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color bgColor;
    Color textColor = Colors.white;
    IconData icon;
    String text;
    
    switch (_request!.status) {
      case RequestStatus.accepted:
        bgColor = AppTheme.accentGreen;
        icon = LucideIcons.circleCheck;
        text = 'Quote Accepted';
        break;
      case RequestStatus.fulfilled:
        bgColor = Colors.blue;
        icon = LucideIcons.packageCheck;
        text = 'Order Completed';
        break;
      case RequestStatus.cancelled:
        bgColor = Colors.red;
        icon = LucideIcons.circleX;
        text = 'Request Cancelled';
        break;
      case RequestStatus.expired:
        bgColor = Colors.orange;
        icon = LucideIcons.clock;
        text = 'Request Expired';
        break;
      case RequestStatus.offered:
        bgColor = Colors.amber;
        textColor = Colors.black;
        icon = LucideIcons.tag;
        text = '${_request!.offerCount} Quotes Received';
        break;
      case RequestStatus.pending:
        bgColor = const Color(0xFF333333);
        icon = LucideIcons.hourglass;
        text = 'Awaiting Quotes';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        _request!.imageUrl!,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: const Color(0xFF2A2A2A),
          child: const Icon(LucideIcons.image, color: Colors.grey, size: 48),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color accentColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard() {
    final shopName = _shop!['name'] as String? ?? 'Unknown Shop';
    final suburb = _shop!['suburb'] as String? ?? '';
    final phone = _shop!['phone'] as String?;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                shopName.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppTheme.accentGreen, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                if (suburb.isNotEmpty)
                  Text(suburb, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),
          if (phone != null)
            IconButton(
              icon: const Icon(LucideIcons.phone, color: AppTheme.accentGreen),
              onPressed: () {
                // TODO: Launch phone dialer
              },
            ),
          IconButton(
            icon: const Icon(LucideIcons.messageCircle, color: AppTheme.accentGreen),
            onPressed: () {
              context.push('/request-chat/${_shop!['id']}', extra: {
                'shopId': _shop!['id'],
                'shopName': shopName,
                'requestId': widget.requestId,
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // View Quotes (if pending/offered)
        if (_request!.status == RequestStatus.pending || _request!.status == RequestStatus.offered)
          ElevatedButton.icon(
            onPressed: () => context.push('/marketplace/${widget.requestId}'),
            icon: const Icon(LucideIcons.tag),
            label: Text(_request!.status == RequestStatus.offered ? 'View Quotes' : 'View Shops'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        
        // Track Order (if accepted/in progress)
        if (_order != null && _request!.status == RequestStatus.accepted)
          ElevatedButton.icon(
            onPressed: () => context.push('/order/${_order!['id']}'),
            icon: const Icon(LucideIcons.truck),
            label: const Text('Track Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        
        const SizedBox(height: 12),
        
        // Contact Support
        OutlinedButton.icon(
          onPressed: () => context.push('/help'),
          icon: Icon(LucideIcons.circleHelp, color: Colors.grey[500]),
          label: const Text('Need Help?'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey,
            side: BorderSide(color: Colors.grey[700]!),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
