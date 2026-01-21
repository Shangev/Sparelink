import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/marketplace.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/skeleton_loader.dart';

/// Quote Comparison Screen
/// Allows mechanics to compare multiple quotes side-by-side
class QuoteComparisonScreen extends ConsumerStatefulWidget {
  final String requestId;

  const QuoteComparisonScreen({super.key, required this.requestId});

  @override
  ConsumerState<QuoteComparisonScreen> createState() => _QuoteComparisonScreenState();
}

class _QuoteComparisonScreenState extends ConsumerState<QuoteComparisonScreen> {
  PartRequest? _request;
  List<Offer> _offers = [];
  List<Offer> _selectedOffers = [];
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'price'; // price, delivery, rating

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Load request details
      final requestData = await supabaseService.getRequest(widget.requestId);
      if (requestData != null) {
        _request = PartRequest.fromJson(requestData);
      }
      
      // Load offers
      final offersData = await supabaseService.getOffersForRequest(widget.requestId);
      _offers = offersData
          .map((data) => Offer.fromJson(data))
          .where((o) => o.status == OfferStatus.pending && !o.isExpired)
          .toList();
      
      _sortOffers();
      
      // Auto-select first two offers for comparison if available
      if (_offers.length >= 2) {
        _selectedOffers = [_offers[0], _offers[1]];
      } else if (_offers.length == 1) {
        _selectedOffers = [_offers[0]];
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _sortOffers() {
    switch (_sortBy) {
      case 'price':
        _offers.sort((a, b) => (a.priceCents + a.deliveryFeeCents)
            .compareTo(b.priceCents + b.deliveryFeeCents));
        break;
      case 'delivery':
        _offers.sort((a, b) => (a.etaMinutes ?? 999).compareTo(b.etaMinutes ?? 999));
        break;
      case 'rating':
        _offers.sort((a, b) => (b.shop?.rating ?? 0).compareTo(a.shop?.rating ?? 0));
        break;
    }
  }

  void _toggleOfferSelection(Offer offer) {
    setState(() {
      if (_selectedOffers.contains(offer)) {
        _selectedOffers.remove(offer);
      } else if (_selectedOffers.length < 3) {
        // Max 3 offers for comparison
        _selectedOffers.add(offer);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can compare up to 3 quotes at a time')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Compare Quotes', style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.arrowUpDown, color: Colors.white),
            color: Colors.grey[900],
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _sortOffers();
              });
            },
            itemBuilder: (context) => [
              _buildSortMenuItem('price', 'Price (Low to High)', LucideIcons.dollarSign),
              _buildSortMenuItem('delivery', 'Delivery Time', LucideIcons.truck),
              _buildSortMenuItem('rating', 'Shop Rating', LucideIcons.star),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonLoader()
          : _error != null
              ? _buildErrorState()
              : _offers.isEmpty
                  ? _buildEmptyState()
                  : _buildContent(),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? AppTheme.accentGreen : Colors.white70),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isSelected ? AppTheme.accentGreen : Colors.white)),
          if (isSelected) ...[
            const Spacer(),
            Icon(LucideIcons.check, size: 16, color: AppTheme.accentGreen),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: SkeletonLoader(height: 180, borderRadius: 16),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.circleAlert, size: 48, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text('Error loading quotes', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.inbox, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No active quotes to compare',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Wait for shops to send quotes for your request',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Request info header
        if (_request != null) _buildRequestHeader(),
        
        // Comparison view (horizontal scroll if offers selected)
        if (_selectedOffers.isNotEmpty) ...[
          _buildComparisonTable(),
          const Divider(color: Colors.white12, height: 1),
        ],
        
        // All offers list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _offers.length,
            itemBuilder: (context, index) {
              final offer = _offers[index];
              final isSelected = _selectedOffers.contains(offer);
              return _QuoteCard(
                offer: offer,
                isSelected: isSelected,
                onSelect: () => _toggleOfferSelection(offer),
                onAccept: () => _acceptOffer(offer),
                onCounterOffer: () => _showCounterOfferDialog(offer),
                showBestValue: index == 0 && _sortBy == 'price',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white.withOpacity(0.05),
      child: Row(
        children: [
          if (_request!.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _request!.imageUrl!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[800],
                  child: const Icon(LucideIcons.image, color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _request!.partName ?? 'Part Request',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  _request!.vehicleDisplay,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_offers.length} ${_offers.length == 1 ? 'quote' : 'quotes'}',
              style: TextStyle(color: AppTheme.accentGreen, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.gitCompare, size: 18, color: AppTheme.accentGreen),
              const SizedBox(width: 8),
              const Text(
                'Side-by-Side Comparison',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_selectedOffers.length}/3 selected',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Labels column
                _buildComparisonLabels(),
                // Offer columns
                ..._selectedOffers.map((offer) => _buildComparisonColumn(offer)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonLabels() {
    return Container(
      width: 100,
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _comparisonLabel('Shop'),
          _comparisonLabel('Price'),
          _comparisonLabel('Delivery'),
          _comparisonLabel('ETA'),
          _comparisonLabel('Rating'),
          _comparisonLabel('Condition'),
          _comparisonLabel('Warranty'),
          _comparisonLabel('Expires'),
        ],
      ),
    );
  }

  Widget _comparisonLabel(String text) {
    return Container(
      height: 36,
      alignment: Alignment.centerLeft,
      child: Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
    );
  }

  Widget _buildComparisonColumn(Offer offer) {
    final isBestPrice = _selectedOffers.every(
      (o) => offer.priceCents + offer.deliveryFeeCents <= o.priceCents + o.deliveryFeeCents
    );
    final isFastestDelivery = _selectedOffers.every(
      (o) => (offer.etaMinutes ?? 999) <= (o.etaMinutes ?? 999)
    );
    
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _comparisonValue(offer.shop?.name ?? 'Unknown', isHighlight: false),
          _comparisonValue(offer.formattedTotal, isHighlight: isBestPrice, highlightColor: AppTheme.accentGreen),
          _comparisonValue(offer.formattedDeliveryFee, isHighlight: false),
          _comparisonValue(offer.formattedEta, isHighlight: isFastestDelivery, highlightColor: Colors.blue),
          _comparisonValue('${offer.shop?.rating?.toStringAsFixed(1) ?? '-'} ★', isHighlight: false),
          _comparisonValue(offer.partCondition ?? '-', isHighlight: false),
          _comparisonValue(offer.warranty ?? '-', isHighlight: false),
          _comparisonValue(offer.expiryLabel, isHighlight: offer.isExpired, highlightColor: Colors.red),
        ],
      ),
    );
  }

  Widget _comparisonValue(String text, {bool isHighlight = false, Color highlightColor = AppTheme.accentGreen}) {
    return Container(
      height: 36,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: isHighlight ? highlightColor : Colors.white,
          fontSize: 13,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _acceptOffer(Offer offer) async {
    // Navigate to shop detail screen to accept
    context.push('/shop/${offer.shopId}/${widget.requestId}', extra: offer);
  }

  Future<void> _showCounterOfferDialog(Offer offer) async {
    final priceController = TextEditingController(
      text: (offer.priceRands * 0.9).toStringAsFixed(0), // Default to 10% less
    );
    final messageController = TextEditingController();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Make Counter-Offer', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original price: ${offer.formattedTotal}',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Your offer (R)',
                labelStyle: TextStyle(color: Colors.grey[500]),
                prefixText: 'R ',
                prefixStyle: const TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.accentGreen),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Message (optional)',
                labelStyle: TextStyle(color: Colors.grey[500]),
                hintText: 'e.g., Can you do better on delivery?',
                hintStyle: TextStyle(color: Colors.grey[600]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.accentGreen),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceController.text);
              if (price != null && price > 0) {
                Navigator.pop(context, {
                  'price': (price * 100).round(),
                  'message': messageController.text,
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
            child: const Text('Send Offer', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    
    if (result != null) {
      await _sendCounterOffer(offer, result['price'], result['message']);
    }
  }

  Future<void> _sendCounterOffer(Offer offer, int priceCents, String message) async {
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      await supabaseService.sendCounterOffer(
        offerId: offer.id,
        counterOfferCents: priceCents,
        message: message,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Counter-offer sent! The shop will be notified.'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _loadData(); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send counter-offer: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// Quote Card Widget
class _QuoteCard extends StatelessWidget {
  final Offer offer;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onAccept;
  final VoidCallback onCounterOffer;
  final bool showBestValue;

  const _QuoteCard({
    required this.offer,
    required this.isSelected,
    required this.onSelect,
    required this.onAccept,
    required this.onCounterOffer,
    this.showBestValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.accentGreen : Colors.white12,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header with shop info and selection
          InkWell(
            onTap: onSelect,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Selection checkbox
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentGreen : Colors.transparent,
                      border: Border.all(color: isSelected ? AppTheme.accentGreen : Colors.grey),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isSelected
                        ? const Icon(LucideIcons.check, size: 16, color: Colors.black)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Shop avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[800],
                    child: Text(
                      offer.shop?.name.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Shop name and rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.shop?.name ?? 'Unknown Shop',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Icon(LucideIcons.star, size: 14, color: Colors.amber[400]),
                            const SizedBox(width: 4),
                            Text(
                              '${offer.shop?.rating?.toStringAsFixed(1) ?? '-'}',
                              style: TextStyle(color: Colors.grey[400], fontSize: 13),
                            ),
                            if (offer.shop?.isVerified ?? false) ...[
                              const SizedBox(width: 8),
                              Icon(LucideIcons.badgeCheck, size: 14, color: Colors.blue[400]),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Best value badge
                  if (showBestValue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Best Value',
                        style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const Divider(color: Colors.white12, height: 1),
          
          // Price and details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(LucideIcons.dollarSign, 'Total', offer.formattedTotal, isLarge: true),
                    _buildInfoItem(LucideIcons.truck, 'Delivery', offer.formattedDeliveryFee),
                    _buildInfoItem(LucideIcons.clock, 'ETA', offer.formattedEta),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (offer.partCondition != null) ...[
                      _buildTag(offer.partCondition!),
                      const SizedBox(width: 8),
                    ],
                    if (offer.warranty != null) ...[
                      _buildTag('${offer.warranty} warranty'),
                      const SizedBox(width: 8),
                    ],
                    // Expiry indicator
                    _buildExpiryTag(offer),
                  ],
                ),
                if (offer.message != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '"${offer.message}"',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: offer.isExpired ? null : onCounterOffer,
                    icon: const Icon(LucideIcons.messageSquare, size: 16),
                    label: const Text('Counter-Offer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.grey[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: offer.isExpired ? null : onAccept,
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, {bool isLarge = false}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isLarge ? 18 : 14,
            fontWeight: isLarge ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
    );
  }

  Widget _buildExpiryTag(Offer offer) {
    final isExpired = offer.isExpired;
    final isExpiringSoon = !isExpired && 
        offer.timeUntilExpiry != null && 
        offer.timeUntilExpiry!.inHours < 6;
    
    Color bgColor;
    Color textColor;
    IconData icon;
    
    if (isExpired) {
      bgColor = Colors.red.withOpacity(0.2);
      textColor = Colors.red;
      icon = LucideIcons.circleAlert;
    } else if (isExpiringSoon) {
      bgColor = Colors.orange.withOpacity(0.2);
      textColor = Colors.orange;
      icon = LucideIcons.clock;
    } else {
      bgColor = Colors.green.withOpacity(0.2);
      textColor = Colors.green;
      icon = LucideIcons.clock;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            offer.expiryLabel,
            style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
