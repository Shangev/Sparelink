/// SpareLink Data Models
/// Core models for the marketplace flow

import 'dart:convert';

// ============================================================================
// SHOP MODEL
// ============================================================================

/// Represents a spare parts shop in the marketplace
class Shop {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double? lat;
  final double? lng;
  final double? rating;
  final int? reviewCount;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime? createdAt;

  Shop({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.lat,
    this.lng,
    this.rating,
    this.reviewCount,
    this.avatarUrl,
    this.isVerified = false,
    this.createdAt,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'],
      name: json['name'] ?? json['workshop_name'] ?? 'Unknown Shop',
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      rating: json['rating']?.toDouble(),
      reviewCount: json['review_count'],
      avatarUrl: json['avatar_url'],
      isVerified: json['is_verified'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'lat': lat,
      'lng': lng,
      'rating': rating,
      'review_count': reviewCount,
      'avatar_url': avatarUrl,
      'is_verified': isVerified,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Calculate distance in km from user location
  double? distanceFrom(double userLat, double userLng) {
    if (lat == null || lng == null) return null;
    // Haversine formula simplified
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat! - userLat);
    final dLng = _toRadians(lng! - userLng);
    final a = _sin2(dLat / 2) + 
        _cos(userLat) * _cos(lat!) * _sin2(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * 3.14159265359 / 180;
  double _sin2(double x) => _sin(x) * _sin(x);
  double _sin(double x) => x - (x * x * x) / 6;
  double _cos(double x) => 1 - (x * x) / 2;
  double _sqrt(double x) => x > 0 ? x * 0.5 + 0.5 : 0;
  double _atan2(double y, double x) => y / (x + 0.001);
}

// ============================================================================
// OFFER MODEL
// ============================================================================

enum OfferStatus { pending, accepted, rejected, expired }
enum StockStatus { inStock, lowStock, outOfStock, ordered }

/// Represents an offer from a shop for a part request
class Offer {
  final String id;
  final String requestId;
  final String shopId;
  final Shop? shop;
  final int priceCents;
  final int deliveryFeeCents;
  final int? etaMinutes;
  final StockStatus stockStatus;
  final List<String>? partImages;
  final String? message;
  final String? partCondition;
  final String? warranty;
  final OfferStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;  // Quote expiry timestamp
  final int? counterOfferCents;  // Counter-offer from mechanic
  final String? counterOfferMessage;  // Counter-offer message
  final bool isCounterOffer;  // Whether this is a counter-offer response

  Offer({
    required this.id,
    required this.requestId,
    required this.shopId,
    this.shop,
    required this.priceCents,
    required this.deliveryFeeCents,
    this.etaMinutes,
    this.stockStatus = StockStatus.inStock,
    this.partImages,
    this.message,
    this.partCondition,
    this.warranty,
    this.status = OfferStatus.pending,
    required this.createdAt,
    this.expiresAt,
    this.counterOfferCents,
    this.counterOfferMessage,
    this.isCounterOffer = false,
  });
  
  /// Check if the quote has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
  
  /// Time remaining until expiry
  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
  
  /// Human-readable expiry time
  String get expiryLabel {
    if (expiresAt == null) return 'No expiry';
    if (isExpired) return 'Expired';
    final remaining = timeUntilExpiry!;
    if (remaining.inHours < 1) return '${remaining.inMinutes}m left';
    if (remaining.inHours < 24) return '${remaining.inHours}h left';
    return '${remaining.inDays}d left';
  }

  /// Price in Rands
  double get priceRands => priceCents / 100;
  
  /// Delivery fee in Rands
  double get deliveryFeeRands => deliveryFeeCents / 100;
  
  /// Total price in Rands
  double get totalRands => (priceCents + deliveryFeeCents) / 100;

  /// Format price as currency string
  String get formattedPrice => 'R ${priceRands.toStringAsFixed(2)}';
  String get formattedDeliveryFee => 'R ${deliveryFeeRands.toStringAsFixed(2)}';
  String get formattedTotal => 'R ${totalRands.toStringAsFixed(2)}';

  /// Format ETA as human-readable string
  String get formattedEta {
    if (etaMinutes == null) return 'TBD';
    if (etaMinutes! < 60) return '$etaMinutes min';
    if (etaMinutes! < 1440) {
      // Less than a day - show hours
      final hours = etaMinutes! ~/ 60;
      return '${hours}h';
    }
    // Show days
    final days = etaMinutes! ~/ 1440;
    if (days == 1) return 'Same day';
    if (days <= 2) return '1-2 days';
    if (days <= 5) return '3-5 days';
    return '1 week+';
  }

  /// CS-14 FIX: Standardized price parsing helper
  /// Parses cents from various field names, handling both cents (int) and Rands (decimal)
  static int _parseCents(Map<String, dynamic> json, String centsKey, [String? randsKey, String? fallbackKey, int defaultValue = 0]) {
    // Try cents field first (preferred format)
    if (json[centsKey] != null) {
      final value = json[centsKey];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    
    // Try Rands field and convert to cents
    if (randsKey != null && json[randsKey] != null) {
      final value = json[randsKey];
      if (value is num) return (value * 100).round();
    }
    
    // Try fallback field
    if (fallbackKey != null && json[fallbackKey] != null) {
      final value = json[fallbackKey];
      if (value is num) {
        // Heuristic: if value > 1000, assume it's already cents; otherwise Rands
        return value > 1000 ? value.toInt() : (value * 100).round();
      }
    }
    
    return defaultValue;
  }

  /// CS-14 FIX: Simplified price parsing using standardized helper
  factory Offer.fromJson(Map<String, dynamic> json) {
    // CS-14 FIX: Use standardized price parsing
    // Priority: price_cents > part_price > total_price (minus delivery)
    int priceCents = _parseCents(json, 'price_cents', 'part_price', 'price', 0);
    
    // If still 0 and total_price exists, calculate from total
    if (priceCents == 0 && json['total_price'] != null) {
      final totalCents = _parseCents(json, 'total_cents', 'total_price', null, 0);
      final deliveryCents = _parseCents(json, 'delivery_fee_cents', 'delivery_fee', null, 14000);
      priceCents = (totalCents - deliveryCents).clamp(0, totalCents);
    }
    
    // CS-14 FIX: Standardized delivery fee parsing
    int deliveryFeeCents = _parseCents(json, 'delivery_fee_cents', 'delivery_fee', null, 14000);
    
    // Handle ETA: delivery_days to minutes (1 day = 1440 min, but we'll show as hours)
    int? etaMinutes;
    if (json['eta_minutes'] != null) {
      etaMinutes = json['eta_minutes'];
    } else if (json['delivery_days'] != null) {
      // Convert days to approximate minutes for display
      final days = json['delivery_days'] as int;
      etaMinutes = days * 24 * 60; // days to minutes
    }
    
    // CS-14 FIX: Standardized counter offer parsing
    int? counterOfferCents;
    final parsedCounterOffer = _parseCents(json, 'counter_offer_cents', 'counter_offer_price', null, -1);
    if (parsedCounterOffer >= 0) {
      counterOfferCents = parsedCounterOffer;
    }
    
    // Handle nested shop data (from joins)
    Shop? shop;
    if (json['shop'] != null) {
      shop = Shop.fromJson(json['shop']);
    } else if (json['shops'] != null) {
      shop = Shop.fromJson(json['shops']);
    }
    
    return Offer(
      id: json['id'],
      requestId: json['request_id'],
      shopId: json['shop_id'],
      shop: shop,
      priceCents: priceCents,
      deliveryFeeCents: deliveryFeeCents,
      etaMinutes: etaMinutes,
      stockStatus: _parseStockStatus(json['stock_status']),
      partImages: json['part_images'] != null 
          ? List<String>.from(json['part_images']) 
          : null,
      message: json['message'] ?? json['notes'],
      partCondition: json['part_condition'],
      warranty: json['warranty'],
      status: _parseOfferStatus(json['status']),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : null,
      counterOfferCents: counterOfferCents,
      counterOfferMessage: json['counter_offer_message'],
      isCounterOffer: json['is_counter_offer'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'shop_id': shopId,
      'price_cents': priceCents,
      'delivery_fee_cents': deliveryFeeCents,
      'eta_minutes': etaMinutes,
      'stock_status': stockStatus.name,
      'part_images': partImages,
      'message': message,
      'part_condition': partCondition,
      'warranty': warranty,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'counter_offer_cents': counterOfferCents,
      'counter_offer_message': counterOfferMessage,
      'is_counter_offer': isCounterOffer,
    };
  }

  static StockStatus _parseStockStatus(String? status) {
    switch (status) {
      case 'in_stock': return StockStatus.inStock;
      case 'low_stock': return StockStatus.lowStock;
      case 'out_of_stock': return StockStatus.outOfStock;
      case 'ordered': return StockStatus.ordered;
      default: return StockStatus.inStock;
    }
  }

  static OfferStatus _parseOfferStatus(String? status) {
    switch (status) {
      case 'accepted': return OfferStatus.accepted;
      case 'rejected': return OfferStatus.rejected;
      case 'expired': return OfferStatus.expired;
      default: return OfferStatus.pending;
    }
  }
}

// ============================================================================
// ORDER MODEL
// ============================================================================

/// Unified Order Status Enum (CS-15 FIX)
/// Synchronized across Flutter, Next.js Dashboard, and Supabase
/// Maps to database values and provides display labels
enum OrderStatus { 
  pending,        // Dashboard initial status
  confirmed,      // Flutter initial status  
  preparing,      // Both use 'preparing'
  processing,     // Dashboard alias for preparing
  shipped,        // Dashboard uses 'shipped'
  outForDelivery, // Flutter uses 'out_for_delivery'
  delivered,      // Both use 'delivered'
  cancelled       // Both use 'cancelled'
}

/// Extension to provide display labels, database values, and utilities
extension OrderStatusExtension on OrderStatus {
  /// Human-readable label for UI display
  String get label {
    switch (this) {
      case OrderStatus.pending: return 'Pending';
      case OrderStatus.confirmed: return 'Order Confirmed';
      case OrderStatus.preparing: return 'Being Prepared';
      case OrderStatus.processing: return 'Being Prepared';
      case OrderStatus.shipped: return 'Shipped';
      case OrderStatus.outForDelivery: return 'Out for Delivery';
      case OrderStatus.delivered: return 'Delivered';
      case OrderStatus.cancelled: return 'Cancelled';
    }
  }
  
  /// Value to send/receive from Supabase database
  String get databaseValue {
    switch (this) {
      case OrderStatus.pending: return 'pending';
      case OrderStatus.confirmed: return 'confirmed';
      case OrderStatus.preparing: return 'preparing';
      case OrderStatus.processing: return 'processing';
      case OrderStatus.shipped: return 'shipped';
      case OrderStatus.outForDelivery: return 'out_for_delivery';
      case OrderStatus.delivered: return 'delivered';
      case OrderStatus.cancelled: return 'cancelled';
    }
  }
  
  /// Progress percentage (0.0 - 1.0) for UI progress indicators
  double get progress {
    switch (this) {
      case OrderStatus.pending: return 0.1;
      case OrderStatus.confirmed: return 0.25;
      case OrderStatus.preparing: return 0.4;
      case OrderStatus.processing: return 0.4;
      case OrderStatus.shipped: return 0.6;
      case OrderStatus.outForDelivery: return 0.8;
      case OrderStatus.delivered: return 1.0;
      case OrderStatus.cancelled: return 0.0;
    }
  }
  
  /// Check if order is still active (not completed or cancelled)
  bool get isActive {
    return this != OrderStatus.delivered && this != OrderStatus.cancelled;
  }
  
  /// Check if order can be cancelled
  bool get canCancel {
    return this == OrderStatus.pending || 
           this == OrderStatus.confirmed || 
           this == OrderStatus.preparing ||
           this == OrderStatus.processing;
  }
}

enum DeliveryDestination { user, mechanic }

/// Represents an order created from an accepted offer
class Order {
  final String id;
  final String requestId;
  final String offerId;
  final Offer? offer;
  final int totalCents;
  final String paymentMethod;
  final OrderStatus status;
  final DeliveryDestination deliveryTo;
  final String? deliveryAddress;
  final String? driverName;
  final String? driverPhone;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  
  // New fields for enhanced delivery features
  final String? deliveryInstructions;  // Drop-off notes from mechanic
  final String? proofOfDeliveryUrl;    // Photo uploaded by driver
  final double? driverLat;             // Driver's current latitude
  final double? driverLng;             // Driver's current longitude
  final int? etaMinutes;               // Estimated time of arrival
  final DateTime? etaUpdatedAt;        // When ETA was last calculated
  final String? invoiceNumber;         // Invoice number for PDF
  final String? paymentStatus;         // pending, paid, failed
  final String? paymentReference;      // Payment provider reference
  final String? customerName;          // Customer name for invoice
  final String? customerPhone;         // Customer phone
  final String? customerEmail;         // Customer email
  final String? partCategory;          // Part category for invoice
  final String? vehicleInfo;           // Vehicle make/model/year

  Order({
    required this.id,
    required this.requestId,
    required this.offerId,
    this.offer,
    required this.totalCents,
    this.paymentMethod = 'cod',
    this.status = OrderStatus.confirmed,
    this.deliveryTo = DeliveryDestination.user,
    this.deliveryAddress,
    this.driverName,
    this.driverPhone,
    this.deliveredAt,
    required this.createdAt,
    this.deliveryInstructions,
    this.proofOfDeliveryUrl,
    this.driverLat,
    this.driverLng,
    this.etaMinutes,
    this.etaUpdatedAt,
    this.invoiceNumber,
    this.paymentStatus,
    this.paymentReference,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.partCategory,
    this.vehicleInfo,
  });

  /// Total in Rands
  double get totalRands => totalCents / 100;
  String get formattedTotal => 'R ${totalRands.toStringAsFixed(2)}';

  /// Human-readable order ID
  String get displayId => 'SL-${id.substring(0, 8).toUpperCase()}';

  /// Status progress (0.0 - 1.0) - uses unified extension
  double get statusProgress => status.progress;

  /// Human-readable status - uses unified extension
  String get statusLabel => status.label;
  
  /// Check if order is still active
  bool get isActive => status.isActive;
  
  /// Check if order can be cancelled
  bool get canCancel => status.canCancel;

  factory Order.fromJson(Map<String, dynamic> json) {
    // Handle nested part_requests data for invoice
    String? partCategory;
    String? vehicleInfo;
    String? customerName;
    String? customerPhone;
    String? customerEmail;
    
    if (json['part_requests'] != null) {
      final pr = json['part_requests'];
      partCategory = pr['part_category'] ?? pr['part_name'];
      if (pr['vehicle_make'] != null) {
        vehicleInfo = '${pr['vehicle_make']} ${pr['vehicle_model'] ?? ''} ${pr['vehicle_year'] ?? ''}'.trim();
      }
      // Customer info from profiles join
      if (pr['profiles'] != null) {
        customerName = pr['profiles']['full_name'];
        customerPhone = pr['profiles']['phone'];
        customerEmail = pr['profiles']['email'];
      }
    }
    
    return Order(
      id: json['id'],
      requestId: json['request_id'],
      offerId: json['offer_id'],
      offer: json['offer'] != null ? Offer.fromJson(json['offer']) : null,
      totalCents: json['total_cents'] ?? 0,
      paymentMethod: json['payment_method'] ?? 'cod',
      status: _parseOrderStatus(json['status']),
      deliveryTo: json['delivery_to'] == 'mechanic' 
          ? DeliveryDestination.mechanic 
          : DeliveryDestination.user,
      deliveryAddress: json['delivery_address'],
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      deliveredAt: json['delivered_at'] != null 
          ? DateTime.parse(json['delivered_at']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      // New fields
      deliveryInstructions: json['delivery_instructions'],
      proofOfDeliveryUrl: json['proof_of_delivery_url'],
      driverLat: json['driver_lat']?.toDouble(),
      driverLng: json['driver_lng']?.toDouble(),
      etaMinutes: json['eta_minutes'],
      etaUpdatedAt: json['eta_updated_at'] != null 
          ? DateTime.parse(json['eta_updated_at']) 
          : null,
      invoiceNumber: json['invoice_number'],
      paymentStatus: json['payment_status'],
      paymentReference: json['payment_reference'],
      customerName: customerName ?? json['customer_name'],
      customerPhone: customerPhone ?? json['customer_phone'],
      customerEmail: customerEmail ?? json['customer_email'],
      partCategory: partCategory ?? json['part_category'],
      vehicleInfo: vehicleInfo ?? json['vehicle_info'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'offer_id': offerId,
      'total_cents': totalCents,
      'payment_method': paymentMethod,
      'status': status.name,
      'delivery_to': deliveryTo.name,
      'delivery_address': deliveryAddress,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'delivered_at': deliveredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'delivery_instructions': deliveryInstructions,
      'proof_of_delivery_url': proofOfDeliveryUrl,
      'driver_lat': driverLat,
      'driver_lng': driverLng,
      'eta_minutes': etaMinutes,
      'eta_updated_at': etaUpdatedAt?.toIso8601String(),
      'invoice_number': invoiceNumber,
      'payment_status': paymentStatus,
      'payment_reference': paymentReference,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'part_category': partCategory,
      'vehicle_info': vehicleInfo,
    };
  }

  /// Parse order status from Supabase/Dashboard string (CS-15 FIX)
  /// Handles all variations from both Flutter and Dashboard
  static OrderStatus _parseOrderStatus(String? status) {
    if (status == null || status.isEmpty) return OrderStatus.confirmed;
    
    switch (status.toLowerCase()) {
      // Dashboard values
      case 'pending':
        return OrderStatus.pending;
      case 'processing':
        return OrderStatus.processing;
      case 'shipped':
        return OrderStatus.shipped;
      
      // Flutter values  
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'out_for_delivery':
      case 'outfordelivery':
        return OrderStatus.outForDelivery;
      
      // Common values
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      
      default:
        // Log unknown status for debugging but don't crash
        assert(() {
          print('⚠️ Unknown order status: $status, defaulting to confirmed');
          return true;
        }());
        return OrderStatus.confirmed;
    }
  }
}

// ============================================================================
// PART REQUEST MODEL
// ============================================================================

enum RequestStatus { pending, offered, accepted, fulfilled, expired, cancelled }

/// Represents a part request from a user/mechanic
/// 
/// CS-13 FIX: Separated partName and partCategory fields
/// - partName: Specific part name (e.g., "Front Brake Pads")
/// - partCategory: General category (e.g., "Brakes")
class PartRequest {
  final String id;
  final String mechanicId;
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? partName;      // Specific part name (CS-13 FIX)
  final String? partCategory;  // General category (CS-13 FIX)
  final String? description;
  final String? imageUrl;  // Primary part image URL (stored in image_url column)
  final String? suburb;    // Location suburb for shop matching
  final RequestStatus status;
  final int offerCount;
  final int shopCount;  // Total shops that received the request
  final int quotedCount;  // Shops that have sent quotes
  final DateTime createdAt;
  final DateTime? expiresAt;

  PartRequest({
    required this.id,
    required this.mechanicId,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.partName,
    this.partCategory,  // CS-13 FIX: Added separate field
    this.description,
    this.imageUrl,
    this.suburb,
    this.status = RequestStatus.pending,
    this.offerCount = 0,
    this.shopCount = 0,
    this.quotedCount = 0,
    required this.createdAt,
    this.expiresAt,
  });
  
  /// Display name: prefers specific part name, falls back to category (CS-13 FIX)
  String get displayName {
    if (partName != null && partName!.isNotEmpty) return partName!;
    if (partCategory != null && partCategory!.isNotEmpty) return partCategory!;
    return 'Part Request';
  }
  
  /// Full part description for detailed views (CS-13 FIX)
  String get fullPartDescription {
    final parts = <String>[];
    if (partName != null && partName!.isNotEmpty) parts.add(partName!);
    if (partCategory != null && partCategory!.isNotEmpty && partCategory != partName) {
      parts.add('($partCategory)');
    }
    return parts.isNotEmpty ? parts.join(' ') : 'Part Request';
  }

  /// Vehicle display string
  String get vehicleDisplay {
    final parts = <String>[];
    if (vehicleMake != null) parts.add(vehicleMake!);
    if (vehicleModel != null) parts.add(vehicleModel!);
    if (vehicleYear != null) parts.add(vehicleYear.toString());
    return parts.join(' ');
  }

  /// Short ID for display
  String get displayId => 'REQ-${id.substring(0, 6).toUpperCase()}';

  /// Human-readable status
  String get statusLabel {
    switch (status) {
      case RequestStatus.pending: 
        // Show how many shops received the request
        if (shopCount > 0) {
          return '$shopCount shop${shopCount == 1 ? '' : 's'} pending';
        }
        return 'Pending';
      case RequestStatus.offered: 
        // Show how many offers/quotes received
        final count = offerCount > 0 ? offerCount : quotedCount;
        return '$count offer${count == 1 ? '' : 's'}';
      case RequestStatus.accepted: return 'Accepted';
      case RequestStatus.fulfilled: return 'Fulfilled';
      case RequestStatus.expired: return 'Expired';
      case RequestStatus.cancelled: return 'Cancelled';
    }
  }

  /// Time since creation
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// CS-13 FIX: Parse both part_name and part_category as separate fields
  factory PartRequest.fromJson(Map<String, dynamic> json) {
    // Handle image URL - check both image_url (new) and image_urls (legacy)
    String? imageUrl = json['image_url'];
    if (imageUrl == null && json['image_urls'] != null) {
      final urls = json['image_urls'];
      if (urls is List && urls.isNotEmpty) {
        imageUrl = urls.first as String?;
      }
    }
    
    // CS-13 FIX: Parse part_name and part_category separately
    // part_name = specific part (e.g., "Front Brake Pads")
    // part_category = general category (e.g., "Brakes")
    final partName = json['part_name'] as String?;
    final partCategory = json['part_category'] as String?;
    
    return PartRequest(
      id: json['id'] ?? '',
      mechanicId: json['mechanic_id'] ?? '',
      vehicleMake: json['vehicle_make'],
      vehicleModel: json['vehicle_model'],
      vehicleYear: json['vehicle_year'],
      partName: partName,           // CS-13 FIX: Specific part name only
      partCategory: partCategory,   // CS-13 FIX: Category only
      description: json['description'],
      imageUrl: imageUrl,
      suburb: json['suburb'],
      status: _parseRequestStatus(json['status']),
      offerCount: json['offer_count'] ?? 0,
      shopCount: json['shop_count'] ?? 0,
      quotedCount: json['quoted_count'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null 
          ? DateTime.tryParse(json['expires_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mechanic_id': mechanicId,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'part_name': partName,           // CS-13 FIX: Specific part name
      'part_category': partCategory,   // CS-13 FIX: Category
      'description': description,
      'image_url': imageUrl,
      'suburb': suburb,
      'status': status.name,
      'offer_count': offerCount,
      'shop_count': shopCount,
      'quoted_count': quotedCount,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  static RequestStatus _parseRequestStatus(String? status) {
    switch (status) {
      case 'offered': return RequestStatus.offered;
      case 'accepted': return RequestStatus.accepted;
      case 'fulfilled': return RequestStatus.fulfilled;
      case 'expired': return RequestStatus.expired;
      case 'cancelled': return RequestStatus.cancelled;
      default: return RequestStatus.pending;
    }
  }
}
