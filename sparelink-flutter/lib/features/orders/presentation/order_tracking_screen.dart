import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/marketplace.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/invoice_service.dart';

/// Order Tracking Screen
/// Shows real-time delivery status and progress with map, ETA, and invoice
class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Order? _order;
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _orderSubscription;
  GoogleMapController? _mapController;
  bool _showMap = false;
  bool _isDownloadingInvoice = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _orderSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Fetch order from Supabase
      final orderData = await supabaseService.getOrder(widget.orderId);
      
      if (orderData != null) {
        // Handle nested data from joins
        if (orderData['offers'] != null) {
          final offerData = orderData['offers'];
          if (offerData['shops'] != null) {
            offerData['shop'] = offerData['shops'];
          }
          orderData['offer'] = offerData;
        }
        
        _order = Order.fromJson(orderData);
        
        // Subscribe to real-time updates
        _subscribeToOrderUpdates(supabaseService);
      } else {
        _error = 'Order not found';
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load order: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _subscribeToOrderUpdates(SupabaseService supabaseService) {
    _orderSubscription?.unsubscribe();
    _orderSubscription = supabaseService.subscribeToOrder(
      widget.orderId,
      (updatedData) {
        // Refresh order data when it changes
        _loadData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBlack,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGreen),
        ),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(LucideIcons.x, color: Colors.white),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.circleAlert, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Order not found',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order!;

    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(LucideIcons.x, color: Colors.white),
        ),
        title: Text(
          order.displayId,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            _buildStatusHeader(order),
            
            const SizedBox(height: 24),
            
            // ETA Card (if out for delivery)
            if (order.status == OrderStatus.outForDelivery && order.etaMinutes != null)
              _buildETACard(order),
            
            const SizedBox(height: 24),
            
            // Live Map (if out for delivery with driver location)
            if (order.status == OrderStatus.outForDelivery)
              _buildMapSection(order),
            
            const SizedBox(height: 24),
            
            // Progress Timeline
            _buildProgressTimeline(order),
            
            const SizedBox(height: 24),
            
            // Delivery Info Card
            _buildDeliveryInfoCard(order),
            
            // Delivery Instructions (if any)
            if (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty)
              _buildDeliveryInstructionsCard(order),
            
            const SizedBox(height: 16),
            
            // Driver Card (if out for delivery)
            if (order.status == OrderStatus.outForDelivery)
              _buildDriverCard(order),
            
            // Proof of Delivery (if delivered with photo)
            if (order.status == OrderStatus.delivered && order.proofOfDeliveryUrl != null)
              _buildProofOfDeliveryCard(order),
            
            const SizedBox(height: 24),
            
            // Order Summary
            _buildOrderSummary(order),
            
            const SizedBox(height: 24),
            
            // Action Buttons (Invoice, Help, etc.)
            _buildActionButtons(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(Order order) {
    IconData statusIcon;
    String statusMessage;
    
    switch (order.status) {
      case OrderStatus.confirmed:
        statusIcon = LucideIcons.circleCheck;
        statusMessage = 'Your order has been confirmed!';
        break;
      case OrderStatus.preparing:
        statusIcon = LucideIcons.package;
        statusMessage = 'Your part is being prepared';
        break;
      case OrderStatus.outForDelivery:
        statusIcon = LucideIcons.truck;
        statusMessage = 'Your order is on the way!';
        break;
      case OrderStatus.delivered:
        statusIcon = LucideIcons.packageCheck;
        statusMessage = 'Order delivered successfully!';
        break;
      case OrderStatus.cancelled:
        statusIcon = LucideIcons.circleX;
        statusMessage = 'Order was cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentGreen.withOpacity(0.2),
            AppTheme.accentGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: AppTheme.accentGreen, size: 48),
          const SizedBox(height: 16),
          Text(
            statusMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            order.statusLabel,
            style: const TextStyle(
              color: AppTheme.accentGreen,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline(Order order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildTimelineStep(
            OrderStatus.confirmed,
            'Order Confirmed',
            'Your order has been placed',
            0,
            order,
          ),
          _buildTimelineConnector(0, order),
          _buildTimelineStep(
            OrderStatus.preparing,
            'Being Prepared',
            'Shop is preparing your part',
            1,
            order,
          ),
          _buildTimelineConnector(1, order),
          _buildTimelineStep(
            OrderStatus.outForDelivery,
            'Out for Delivery',
            'Driver is on the way',
            2,
            order,
          ),
          _buildTimelineConnector(2, order),
          _buildTimelineStep(
            OrderStatus.delivered,
            'Delivered',
            'Part has been delivered',
            3,
            order,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(OrderStatus status, String title, String subtitle, int index, Order order) {
    final currentIndex = _getStatusIndex(order.status);
    final isCompleted = index < currentIndex;
    final isCurrent = index == currentIndex;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step Indicator
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted || isCurrent
                ? AppTheme.accentGreen
                : Colors.white.withOpacity(0.1),
            border: isCurrent
                ? Border.all(color: AppTheme.accentGreen, width: 3)
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(LucideIcons.check, color: Colors.black, size: 16)
                : isCurrent
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                        ),
                      )
                    : null,
          ),
        ),
        const SizedBox(width: 16),
        // Step Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isCompleted || isCurrent ? Colors.white : Colors.white.withOpacity(0.4),
                    fontSize: 15,
                    fontWeight: isCompleted || isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector(int index, Order order) {
    final currentIndex = _getStatusIndex(order.status);
    final isCompleted = index < currentIndex;
    
    return Row(
      children: [
        const SizedBox(width: 13),
        Container(
          width: 2,
          height: 30,
          color: isCompleted ? AppTheme.accentGreen : Colors.white.withOpacity(0.1),
        ),
      ],
    );
  }

  int _getStatusIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed: return 0;
      case OrderStatus.preparing: return 1;
      case OrderStatus.outForDelivery: return 2;
      case OrderStatus.delivered: return 3;
      case OrderStatus.cancelled: return -1;
    }
  }

  Widget _buildDeliveryInfoCard(Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.mapPin, color: AppTheme.accentGreen),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.deliveryTo == DeliveryDestination.user
                      ? 'Delivering to You'
                      : 'Delivering to Mechanic',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.deliveryAddress ?? 'Address pending',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Driver Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                order.driverName?.substring(0, 1) ?? 'D',
                style: const TextStyle(
                  color: AppTheme.accentGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Driver Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.driverName ?? 'Driver',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your delivery driver',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Call Button
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling ${order.driverPhone}...')),
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(LucideIcons.phone, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(Order order) {
    final offer = order.offer;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shop',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              Text(
                offer?.shop?.name ?? 'Shop',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              Text(
                order.paymentMethod == 'cod' ? 'Cash on Delivery' : order.paymentMethod,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                order.formattedTotal,
                style: const TextStyle(
                  color: AppTheme.accentGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildETACard(Order order) {
    final eta = order.etaMinutes ?? 0;
    final hours = eta ~/ 60;
    final minutes = eta % 60;
    String etaText;
    
    if (hours > 0) {
      etaText = '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    } else {
      etaText = '$minutes min';
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentGreen.withOpacity(0.2),
            AppTheme.accentGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.clock, color: Colors.black, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated Arrival',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  etaText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (order.etaUpdatedAt != null)
                  Text(
                    'Updated ${_formatTimeAgo(order.etaUpdatedAt!)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} hr ago';
  }

  Widget _buildMapSection(Order order) {
    final hasDriverLocation = order.driverLat != null && order.driverLng != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle Map Button
        GestureDetector(
          onTap: () => setState(() => _showMap = !_showMap),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.map,
                  color: hasDriverLocation ? AppTheme.accentGreen : Colors.white54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasDriverLocation ? 'Track Driver Live' : 'Live Tracking',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  _showMap ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
        
        // Map View (expandable)
        if (_showMap) ...[
          const SizedBox(height: 12),
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasDriverLocation
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(order.driverLat!, order.driverLng!),
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('driver'),
                        position: LatLng(order.driverLat!, order.driverLng!),
                        infoWindow: InfoWindow(title: order.driverName ?? 'Driver'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      ),
                    },
                    onMapCreated: (controller) => _mapController = controller,
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.mapPinOff, size: 48, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Driver location not available yet',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeliveryInstructionsCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.messageSquare, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Instructions',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.deliveryInstructions!,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofOfDeliveryCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.camera, color: AppTheme.accentGreen, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Proof of Delivery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Icon(LucideIcons.circleCheck, color: AppTheme.accentGreen, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showFullImage(order.proofOfDeliveryUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                order.proofOfDeliveryUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 180,
                    color: Colors.white.withOpacity(0.1),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.accentGreen),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: Colors.white.withOpacity(0.1),
                  child: const Center(
                    child: Icon(LucideIcons.imageOff, color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to view full image',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(LucideIcons.x, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final order = _order;
    
    return Column(
      children: [
        // Download Invoice Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isDownloadingInvoice ? null : _downloadInvoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isDownloadingInvoice
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(LucideIcons.fileText, size: 18),
            label: Text(_isDownloadingInvoice ? 'Generating...' : 'Download Invoice'),
          ),
        ),
        const SizedBox(height: 12),
        
        // Return to Home
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(LucideIcons.house, size: 18),
            label: const Text('Return to Home'),
          ),
        ),
        const SizedBox(height: 12),
        
        // View Order History
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/orders'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(LucideIcons.history, size: 18),
            label: const Text('Order History'),
          ),
        ),
        const SizedBox(height: 12),
        
        // Contact Support
        SizedBox(
          width: double.infinity,
          height: 52,
          child: TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support chat coming soon!')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.7),
            ),
            icon: const Icon(LucideIcons.circleHelp, size: 18),
            label: const Text('Need Help?'),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadInvoice() async {
    if (_order == null) return;
    
    setState(() => _isDownloadingInvoice = true);
    
    try {
      final invoiceService = InvoiceService();
      await invoiceService.shareInvoice(_order!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice ready!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingInvoice = false);
      }
    }
  }
}
