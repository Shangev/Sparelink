import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/marketplace.dart';
import '../../../shared/services/supabase_service.dart';

/// Marketplace Results Screen
/// Shows available shop offers for a part request (Uber Eats style)
class MarketplaceResultsScreen extends ConsumerStatefulWidget {
  final String requestId;

  const MarketplaceResultsScreen({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<MarketplaceResultsScreen> createState() => _MarketplaceResultsScreenState();
}

class _MarketplaceResultsScreenState extends ConsumerState<MarketplaceResultsScreen> {
  PartRequest? _request;
  List<Offer> _offers = [];
  List<Map<String, dynamic>> _nearbyShops = []; // Shops in the area
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'price'; // price, distance, rating, eta
  RealtimeChannel? _offersSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToNewOffers();
  }
  
  @override
  void dispose() {
    _offersSubscription?.unsubscribe();
    super.dispose();
  }
  
  /// Subscribe to real-time quote notifications
  void _subscribeToNewOffers() {
    final supabaseService = ref.read(supabaseServiceProvider);
    _offersSubscription = supabaseService.subscribeToOffersForRequest(
      widget.requestId,
      (newOffer) {
        // A new quote arrived! Show notification and refresh
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.bell, color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('New quote received!')),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.black,
                onPressed: _loadData,
              ),
            ),
          );
          _loadData(); // Refresh the list
        }
      },
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Fetch request details from Supabase
      final requestData = await supabaseService.getRequest(widget.requestId);
      if (requestData != null) {
        _request = PartRequest.fromJson(requestData);
      }
      
      // Fetch offers for this request from Supabase
      final offersData = await supabaseService.getOffersForRequest(widget.requestId);
      _offers = offersData.map((data) {
        // Handle nested shop data from the join query
        if (data['shops'] != null) {
          data['shop'] = data['shops'];
        }
        return Offer.fromJson(data);
      }).toList();
      
      // Also fetch nearby shops (regardless of whether they've sent offers)
      await _loadNearbyShops();
      
      _sortOffers();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load offers: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadNearbyShops() async {
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Get shops in the area (use request suburb or user location)
      final suburb = _request?.suburb;
      if (suburb != null && suburb.isNotEmpty) {
        // Fetch shops that service this area
        final shopsData = await supabaseService.getShopsBySuburb(suburb: suburb, limit: 20);
        _nearbyShops = shopsData;
      } else {
        // Fallback: get all active shops
        final shopsData = await supabaseService.getAllShops();
        _nearbyShops = shopsData;
      }
    } catch (e) {
      // Don't fail the whole load if nearby shops fail
      print('Failed to load nearby shops: $e');
      _nearbyShops = [];
    }
  }
  
  // Get total available shops (either with offers or nearby)
  int get _totalShopsAvailable {
    // Combine shops with offers + nearby shops (avoiding duplicates)
    final shopIdsWithOffers = _offers.map((o) => o.shopId).toSet();
    final nearbyShopIds = _nearbyShops.map((s) => s['id'] as String).toSet();
    return shopIdsWithOffers.union(nearbyShopIds).length;
  }

  void _sortOffers() {
    switch (_sortBy) {
      case 'price':
        // Sort by total price (part + delivery)
        _offers.sort((a, b) => (a.priceCents + a.deliveryFeeCents).compareTo(b.priceCents + b.deliveryFeeCents));
        break;
      case 'eta':
        _offers.sort((a, b) => (a.etaMinutes ?? 999).compareTo(b.etaMinutes ?? 999));
        break;
      case 'rating':
        _offers.sort((a, b) => (b.shop?.rating ?? 0).compareTo(a.shop?.rating ?? 0));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;
    
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                // Header
                _buildHeader(isDesktop),
                
                // Error State
                if (_error != null && !_isLoading)
                  _buildErrorState(),
                
                // Request Summary Card
                if (!_isLoading && _error == null && _request != null) _buildRequestSummary(),
                
                // Sort Options
                if (!_isLoading && _error == null) _buildSortOptions(),
                
                // Results List
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _error != null
                          ? const SizedBox()
                          : _offers.isEmpty
                              ? _buildEmptyState()
                              : _buildOffersList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.circleAlert, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Something went wrong',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    // Use total shops available (offers + nearby shops)
    final shopCount = _totalShopsAvailable;
    final offerCount = _offers.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoading ? 'Finding shops...' : '$shopCount Shops Available',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isLoading && offerCount > 0)
                  Text(
                    '$offerCount ${offerCount == 1 ? 'quote' : 'quotes'} received',
                    style: TextStyle(
                      color: AppTheme.accentGreen,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          // Compare Quotes button (shown when 2+ quotes)
          if (!_isLoading && offerCount >= 2)
            TextButton.icon(
              onPressed: () => context.push('/compare-quotes/${widget.requestId}'),
              icon: const Icon(LucideIcons.gitCompare, size: 16),
              label: const Text('Compare'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentGreen,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSummary() {
    final request = _request!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Part Image Placeholder or actual image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: request.imageUrl != null && request.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      request.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(LucideIcons.car, color: AppTheme.accentGreen, size: 28),
                    ),
                  )
                : const Icon(LucideIcons.car, color: AppTheme.accentGreen, size: 28),
          ),
          const SizedBox(width: 16),
          // Request Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.vehicleDisplay,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.partName ?? 'Part Request',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              request.statusLabel,
              style: const TextStyle(
                color: AppTheme.accentGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortOptions() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSortChip('Price', 'price', LucideIcons.dollarSign),
          _buildSortChip('ETA', 'eta', LucideIcons.clock),
          _buildSortChip('Rating', 'rating', LucideIcons.star),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
          _sortOffers();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentGreen : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppTheme.accentGreen : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.accentGreen),
          const SizedBox(height: 24),
          Text(
            'Searching nearby shops...',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // If we have nearby shops but no offers yet, show them
    if (_nearbyShops.isNotEmpty) {
      return _buildNearbyShopsList();
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.searchX, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 24),
          const Text(
            'No offers yet',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Shops are reviewing your request.\nPull down to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNearbyShopsList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _nearbyShops.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, color: AppTheme.accentGreen, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Shops in Your Area',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'These shops can fulfill your request. Chat with them or wait for quotes.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            );
          }
          
          final shop = _nearbyShops[index - 1];
          return _NearbyShopCard(
            shop: shop,
            requestId: widget.requestId,
            onChat: () => _openChatWithShop(shop),
            onTap: () {
              context.push('/shop/${shop['id']}', extra: {
                'requestId': widget.requestId,
              });
            },
          );
        },
      ),
    );
  }
  
  void _openChatWithShop(Map<String, dynamic> shop) {
    // Navigate to chat with this shop for this request
    context.push('/request-chat/${shop['id']}', extra: {
      'shopId': shop['id'],
      'shopName': shop['name'],
      'requestId': widget.requestId,
    });
  }

  Widget _buildOffersList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _offers.length,
        itemBuilder: (context, index) {
          return _OfferCard(
            offer: _offers[index],
            onTap: () {
              context.push('/shop/${_offers[index].shopId}/${widget.requestId}', extra: _offers[index]);
            },
            onChat: () {
              // TODO: Open chat with shop
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat feature coming soon!')),
              );
            },
          );
        },
      ),
    );
  }
}

/// Offer Card Widget - Uber Eats style
class _OfferCard extends StatelessWidget {
  final Offer offer;
  final VoidCallback onTap;
  final VoidCallback onChat;

  const _OfferCard({
    required this.offer,
    required this.onTap,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final shop = offer.shop;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop Info Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Shop Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        shop?.name.substring(0, 1) ?? 'S',
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Shop Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shop?.name ?? 'Unknown Shop',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (shop?.isVerified ?? false)
                              const Icon(LucideIcons.badgeCheck, color: AppTheme.accentGreen, size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (shop?.rating != null) ...[
                              const Icon(LucideIcons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                shop!.rating!.toStringAsFixed(1),
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(LucideIcons.clock, color: Colors.white.withOpacity(0.5), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              offer.formattedEta,
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
            
            // Offer Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Stock Status
                  _buildStatusBadge(offer.stockStatus),
                  const SizedBox(width: 12),
                  // Condition
                  if (offer.partCondition != null)
                    Expanded(
                      child: Text(
                        offer.partCondition!,
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ),
                  // Total Price (includes delivery)
                  Text(
                    offer.formattedTotal,
                    style: const TextStyle(
                      color: AppTheme.accentGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Message (if any)
            if (offer.message != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Text(
                  offer.message!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            
            // Action Buttons
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Row(
                children: [
                  // Chat Button
                  OutlinedButton.icon(
                    onPressed: onChat,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(LucideIcons.messageCircle, size: 16),
                    label: const Text('Chat'),
                  ),
                  const Spacer(),
                  // View Button
                  ElevatedButton.icon(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    icon: const Icon(LucideIcons.arrowRight, size: 16),
                    label: const Text('View Offer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(StockStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case StockStatus.inStock:
        color = AppTheme.accentGreen;
        label = 'In Stock';
        break;
      case StockStatus.lowStock:
        color = Colors.orange;
        label = 'Low Stock';
        break;
      case StockStatus.outOfStock:
        color = Colors.red;
        label = 'Out of Stock';
        break;
      case StockStatus.ordered:
        color = Colors.blue;
        label = 'On Order';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Nearby Shop Card - shown when no offers yet but shops are in the area
class _NearbyShopCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final String requestId;
  final VoidCallback onTap;
  final VoidCallback onChat;

  const _NearbyShopCard({
    required this.shop,
    required this.requestId,
    required this.onTap,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final shopName = shop['name'] as String? ?? 'Unknown Shop';
    final suburb = shop['suburb'] as String? ?? '';
    final rating = shop['rating'] as num?;
    final isVerified = shop['is_verified'] as bool? ?? false;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            // Shop Avatar
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
                  style: const TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Shop Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shopName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isVerified)
                        const Icon(LucideIcons.badgeCheck, color: AppTheme.accentGreen, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (rating != null) ...[
                        const Icon(LucideIcons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (suburb.isNotEmpty) ...[
                        Icon(LucideIcons.mapPin, color: Colors.grey[500], size: 12),
                        const SizedBox(width: 4),
                        Text(
                          suburb,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Chat Button
            OutlinedButton.icon(
              onPressed: onChat,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentGreen,
                side: const BorderSide(color: AppTheme.accentGreen),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
              ),
              icon: const Icon(LucideIcons.messageCircle, size: 14),
              label: const Text('Chat', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
