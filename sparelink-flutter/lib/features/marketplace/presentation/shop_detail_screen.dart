import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/marketplace.dart';
import '../../../shared/services/supabase_service.dart';

/// Shop Detail Screen
/// View shop details, part info, and confirm order
class ShopDetailScreen extends ConsumerStatefulWidget {
  final String shopId;
  final String requestId;
  final Offer? offer; // Passed from marketplace screen

  const ShopDetailScreen({
    super.key,
    required this.shopId,
    required this.requestId,
    this.offer,
  });

  @override
  ConsumerState<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends ConsumerState<ShopDetailScreen> {
  late Offer _offer;
  DeliveryDestination _deliveryTo = DeliveryDestination.user;
  bool _isLoading = true;
  bool _isOrdering = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.offer != null) {
      _offer = widget.offer!;
      setState(() => _isLoading = false);
      return;
    }

    // Load from Supabase
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final offersData = await supabaseService.getOffersForRequest(widget.requestId);
      
      if (offersData.isNotEmpty) {
        // Find the offer for this shop
        final offerData = offersData.firstWhere(
          (o) => o['shop_id'] == widget.shopId,
          orElse: () => offersData.first,
        );
        
        // Handle nested shop data
        if (offerData['shops'] != null) {
          offerData['shop'] = offerData['shops'];
        }
        
        _offer = Offer.fromJson(offerData);
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      // Show error and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load offer: ${e.toString()}')),
        );
        context.pop();
      }
    }
  }

  Future<void> _confirmOrder() async {
    setState(() => _isOrdering = true);

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Create order in Supabase
      final order = await supabaseService.acceptOffer(
        offerId: _offer.id,
        requestId: widget.requestId,
        totalCents: _offer.priceCents + _offer.deliveryFeeCents,
        deliveryDestination: _deliveryTo == DeliveryDestination.user ? 'user' : 'mechanic',
        deliveryAddress: _deliveryTo == DeliveryDestination.user 
            ? 'Your current location' 
            : 'Workshop address',
      );

      if (mounted) {
        // Navigate to order tracking with real order ID
        context.push('/order/${order['id']}');
      }
    } catch (e) {
      setState(() => _isOrdering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _rejectOffer() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Reject Offer', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reject this offer from ${_offer.shop?.name ?? 'this shop'}?',
          style: const TextStyle(color: Colors.white70),
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

    setState(() => _isOrdering = true);

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Reject the offer
      await supabaseService.rejectOffer(
        offerId: _offer.id,
        requestId: widget.requestId,
        shopId: widget.shopId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        // Go back to previous screen
        context.pop();
      }
    } catch (e) {
      setState(() => _isOrdering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject offer: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGreen),
        ),
      );
    }

    final shop = _offer.shop;

    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: CustomScrollView(
        slivers: [
          // App Bar with Shop Header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.darkGray,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  // TODO: Open chat
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat feature coming soon!')),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.messageCircle, color: Colors.white, size: 20),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.accentGreen.withOpacity(0.3),
                      AppTheme.darkGray,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Shop Avatar
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.accentGreen, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            shop?.name.substring(0, 1) ?? 'S',
                            style: const TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Shop Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            shop?.name ?? 'Shop',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (shop?.isVerified ?? false) ...[
                            const SizedBox(width: 8),
                            const Icon(LucideIcons.badgeCheck, color: AppTheme.accentGreen, size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Rating & Reviews
                      if (shop?.rating != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${shop!.rating!.toStringAsFixed(1)} (${shop.reviewCount} reviews)',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Part Details Card
                  _buildSectionTitle('Part Details'),
                  const SizedBox(height: 12),
                  _buildPartDetailsCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Price Breakdown Card
                  _buildSectionTitle('Price Breakdown'),
                  const SizedBox(height: 12),
                  _buildPriceBreakdownCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Delivery Options
                  _buildSectionTitle('Delivery To'),
                  const SizedBox(height: 12),
                  _buildDeliveryOptions(),
                  
                  const SizedBox(height: 24),
                  
                  // Shop Message
                  if (_offer.message != null) ...[
                    _buildSectionTitle('Shop Message'),
                    const SizedBox(height: 12),
                    _buildShopMessageCard(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Order Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isOrdering ? null : _confirmOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isOrdering
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.shoppingBag, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Confirm Order • ${_offer.formattedTotal}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Reject Offer Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isOrdering ? null : _rejectOffer,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(LucideIcons.x, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Reject Offer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Payment Note
                  Center(
                    child: Text(
                      'Cash on Delivery',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPartDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildDetailRow(LucideIcons.package, 'Condition', _offer.partCondition ?? 'New'),
          const SizedBox(height: 12),
          _buildDetailRow(LucideIcons.shield, 'Warranty', _offer.warranty ?? 'No warranty'),
          const SizedBox(height: 12),
          _buildDetailRow(LucideIcons.clock, 'Estimated Delivery', _offer.formattedEta),
          const SizedBox(height: 12),
          _buildDetailRow(
            LucideIcons.circleCheck,
            'Stock Status',
            _getStockLabel(_offer.stockStatus),
            valueColor: _getStockColor(_offer.stockStatus),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.5), size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildPriceRow('Part Price', _offer.formattedPrice),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Delivery Fee',
            _offer.deliveryFeeCents == 0 ? 'FREE' : _offer.formattedDeliveryFee,
            valueColor: _offer.deliveryFeeCents == 0 ? AppTheme.accentGreen : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24),
          ),
          _buildPriceRow('Total', _offer.formattedTotal, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.white.withOpacity(0.7),
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (isTotal ? AppTheme.accentGreen : Colors.white),
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOptions() {
    return Column(
      children: [
        _buildDeliveryOption(
          DeliveryDestination.user,
          'Deliver to Me',
          'Your current location',
          LucideIcons.mapPin,
        ),
        const SizedBox(height: 12),
        _buildDeliveryOption(
          DeliveryDestination.mechanic,
          'Deliver to Mechanic',
          'Workshop address',
          LucideIcons.wrench,
        ),
      ],
    );
  }

  Widget _buildDeliveryOption(
    DeliveryDestination destination,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _deliveryTo == destination;
    
    return GestureDetector(
      onTap: () => setState(() => _deliveryTo = destination),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentGreen.withOpacity(0.1) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentGreen : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.accentGreen : Colors.white.withOpacity(0.5)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.accentGreen : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.accentGreen : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(LucideIcons.check, color: AppTheme.accentGreen, size: 14),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopMessageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.messageSquare, color: Colors.white.withOpacity(0.5), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _offer.message!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStockLabel(StockStatus status) {
    switch (status) {
      case StockStatus.inStock: return 'In Stock';
      case StockStatus.lowStock: return 'Low Stock';
      case StockStatus.outOfStock: return 'Out of Stock';
      case StockStatus.ordered: return 'On Order';
    }
  }

  Color _getStockColor(StockStatus status) {
    switch (status) {
      case StockStatus.inStock: return AppTheme.accentGreen;
      case StockStatus.lowStock: return Colors.orange;
      case StockStatus.outOfStock: return Colors.red;
      case StockStatus.ordered: return Colors.blue;
    }
  }
}
