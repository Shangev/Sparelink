/// Payment Models for SpareLink
/// Handles payment processing, saved cards, refunds, and transaction history

// ============================================================================
// PAYMENT RESULT (CS-18 FIX: Added gatewayResponse and requiresManualCheck)
// ============================================================================

/// Result from a payment attempt
/// 
/// CS-18 FIX: Added fields for proper error handling:
/// - [gatewayResponse]: The raw response from Paystack explaining why payment failed
/// - [requiresManualCheck]: True if verification failed but money may have been deducted
class PaymentResult {
  final bool success;
  final String reference;
  final String message;
  final String? authorizationCode;
  final String? cardLast4;
  final String? cardBrand;
  final String? transactionId;
  final String? gatewayResponse;      // CS-18: Paystack gateway response (e.g., "Insufficient funds")
  final bool requiresManualCheck;     // CS-18: True if user should check bank statement

  PaymentResult({
    required this.success,
    required this.reference,
    required this.message,
    this.authorizationCode,
    this.cardLast4,
    this.cardBrand,
    this.transactionId,
    this.gatewayResponse,
    this.requiresManualCheck = false,
  });

  /// Check if payment needs manual verification/support contact
  bool get needsSupport => requiresManualCheck || (!success && gatewayResponse == null);
  
  /// User-friendly error message for display
  String get userMessage {
    if (success) return 'Payment successful!';
    if (gatewayResponse != null && gatewayResponse!.isNotEmpty) {
      return gatewayResponse!;
    }
    if (requiresManualCheck) {
      return 'We couldn\'t verify your payment. Please check your bank statement and contact support if money was deducted.';
    }
    return message;
  }
  
  /// Get display-friendly status
  String get statusLabel {
    if (success) return 'Successful';
    if (requiresManualCheck) return 'Verification Required';
    return 'Failed';
  }

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      success: json['success'] ?? false,
      reference: json['reference'] ?? '',
      message: json['message'] ?? '',
      authorizationCode: json['authorization_code'],
      cardLast4: json['card_last4'],
      cardBrand: json['card_brand'],
      transactionId: json['transaction_id'],
      gatewayResponse: json['gateway_response'],
      requiresManualCheck: json['requires_manual_check'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'reference': reference,
      'message': message,
      'authorization_code': authorizationCode,
      'card_last4': cardLast4,
      'card_brand': cardBrand,
      'transaction_id': transactionId,
      'gateway_response': gatewayResponse,
      'requires_manual_check': requiresManualCheck,
    };
  }
}

// ============================================================================
// SAVED CARD (TOKENIZATION)
// ============================================================================

/// Represents a saved payment card (tokenized)
class SavedCard {
  final String id;
  final String authorizationCode;
  final String email;
  final String last4;
  final String brand;
  final String expMonth;
  final String expYear;
  final String cardType;
  final String bank;
  final bool isDefault;
  final DateTime createdAt;

  SavedCard({
    required this.id,
    required this.authorizationCode,
    required this.email,
    required this.last4,
    required this.brand,
    required this.expMonth,
    required this.expYear,
    required this.cardType,
    required this.bank,
    required this.isDefault,
    required this.createdAt,
  });

  /// Get formatted card number display (e.g., "**** **** **** 1234")
  String get maskedNumber => '**** **** **** $last4';

  /// Get formatted expiry (e.g., "12/25")
  String get expiryDate => '$expMonth/$expYear';

  /// Check if card is expired
  bool get isExpired {
    final now = DateTime.now();
    final expiry = DateTime(
      2000 + int.parse(expYear),
      int.parse(expMonth) + 1,
      0,
    );
    return now.isAfter(expiry);
  }

  /// Get card icon based on brand
  String get brandIcon {
    switch (brand.toLowerCase()) {
      case 'visa':
        return '💳'; // In real app, use actual card brand icons
      case 'mastercard':
        return '💳';
      case 'verve':
        return '💳';
      default:
        return '💳';
    }
  }

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: json['id'] ?? '',
      authorizationCode: json['authorization_code'] ?? '',
      email: json['email'] ?? '',
      last4: json['last4'] ?? '',
      brand: json['brand'] ?? 'Unknown',
      expMonth: json['exp_month'] ?? '',
      expYear: json['exp_year'] ?? '',
      cardType: json['card_type'] ?? 'debit',
      bank: json['bank'] ?? '',
      isDefault: json['is_default'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorization_code': authorizationCode,
      'email': email,
      'last4': last4,
      'brand': brand,
      'exp_month': expMonth,
      'exp_year': expYear,
      'card_type': cardType,
      'bank': bank,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// ============================================================================
// REFUND REQUEST
// ============================================================================

/// Status of a refund request
enum RefundStatus {
  pending,
  approved,
  rejected,
  processed,
}

/// Reason categories for refund requests
enum RefundReason {
  wrongPart,
  damagedPart,
  notDelivered,
  qualityIssue,
  changedMind,
  other,
}

extension RefundReasonExtension on RefundReason {
  String get displayName {
    switch (this) {
      case RefundReason.wrongPart:
        return 'Wrong Part Received';
      case RefundReason.damagedPart:
        return 'Part Arrived Damaged';
      case RefundReason.notDelivered:
        return 'Order Not Delivered';
      case RefundReason.qualityIssue:
        return 'Quality Issue';
      case RefundReason.changedMind:
        return 'Changed My Mind';
      case RefundReason.other:
        return 'Other Reason';
    }
  }

  String get description {
    switch (this) {
      case RefundReason.wrongPart:
        return 'The part received does not match what was ordered';
      case RefundReason.damagedPart:
        return 'The part was damaged during shipping or handling';
      case RefundReason.notDelivered:
        return 'The order was never delivered';
      case RefundReason.qualityIssue:
        return 'The part quality does not meet expectations';
      case RefundReason.changedMind:
        return 'I no longer need this part';
      case RefundReason.other:
        return 'Please describe the issue below';
    }
  }
}

/// Represents a refund request
class RefundRequest {
  final String id;
  final String userId;
  final String orderId;
  final String reason;
  final String? description;
  final List<String>? photoUrls;
  final RefundStatus status;
  final int? refundAmountCents;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? processedAt;
  final Map<String, dynamic>? orderDetails;

  RefundRequest({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.reason,
    this.description,
    this.photoUrls,
    required this.status,
    this.refundAmountCents,
    this.adminNotes,
    required this.createdAt,
    this.processedAt,
    this.orderDetails,
  });

  /// Get formatted refund amount
  String get formattedRefundAmount {
    if (refundAmountCents == null) return 'TBD';
    return 'R ${(refundAmountCents! / 100).toStringAsFixed(2)}';
  }

  /// Check if refund is still pending
  bool get isPending => status == RefundStatus.pending;

  /// Get status display color
  String get statusColor {
    switch (status) {
      case RefundStatus.pending:
        return 'orange';
      case RefundStatus.approved:
        return 'blue';
      case RefundStatus.rejected:
        return 'red';
      case RefundStatus.processed:
        return 'green';
    }
  }

  factory RefundRequest.fromJson(Map<String, dynamic> json) {
    return RefundRequest(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      orderId: json['order_id'] ?? '',
      reason: json['reason'] ?? '',
      description: json['description'],
      photoUrls: json['photo_urls'] != null
          ? List<String>.from(json['photo_urls'])
          : null,
      status: _parseRefundStatus(json['status']),
      refundAmountCents: json['refund_amount_cents'],
      adminNotes: json['admin_notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      orderDetails: json['orders'],
    );
  }

  static RefundStatus _parseRefundStatus(String? status) {
    switch (status) {
      case 'approved':
        return RefundStatus.approved;
      case 'rejected':
        return RefundStatus.rejected;
      case 'processed':
        return RefundStatus.processed;
      default:
        return RefundStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'order_id': orderId,
      'reason': reason,
      'description': description,
      'photo_urls': photoUrls,
      'status': status.name,
      'refund_amount_cents': refundAmountCents,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
    };
  }
}

/// Result from a refund request submission
class RefundResult {
  final bool success;
  final String message;
  final String? refundId;

  RefundResult({
    required this.success,
    required this.message,
    this.refundId,
  });
}

// ============================================================================
// PAYMENT TRANSACTION
// ============================================================================

/// Status of a payment transaction
enum TransactionStatus {
  pending,
  success,
  failed,
  refunded,
}

/// Represents a payment transaction in history
class PaymentTransaction {
  final String id;
  final String userId;
  final String orderId;
  final String reference;
  final int amountCents;
  final String currency;
  final TransactionStatus status;
  final String provider;
  final String? email;
  final String? cardLast4;
  final String? cardBrand;
  final DateTime createdAt;
  final Map<String, dynamic>? orderDetails;

  PaymentTransaction({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.reference,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.provider,
    this.email,
    this.cardLast4,
    this.cardBrand,
    required this.createdAt,
    this.orderDetails,
  });

  /// Get formatted amount (e.g., "R 1,234.56")
  String get formattedAmount {
    final amount = amountCents / 100;
    return 'R ${amount.toStringAsFixed(2)}';
  }

  /// Get masked card display
  String? get maskedCard {
    if (cardLast4 == null) return null;
    return '**** $cardLast4';
  }

  /// Get payment method display
  String get paymentMethodDisplay {
    if (cardBrand != null && cardLast4 != null) {
      return '${cardBrand!} •••• $cardLast4';
    }
    return provider.toUpperCase();
  }

  /// Get status display text
  String get statusDisplay {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.success:
        return 'Successful';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }

  /// Get order info if available
  String? get partName {
    if (orderDetails == null) return null;
    final offer = orderDetails!['offers'];
    if (offer == null) return null;
    return offer['part_name'];
  }

  String? get shopName {
    if (orderDetails == null) return null;
    final offer = orderDetails!['offers'];
    if (offer == null) return null;
    final shop = offer['shops'];
    if (shop == null) return null;
    return shop['name'];
  }

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      orderId: json['order_id'] ?? '',
      reference: json['reference'] ?? '',
      amountCents: json['amount_cents'] ?? 0,
      currency: json['currency'] ?? 'ZAR',
      status: _parseTransactionStatus(json['status']),
      provider: json['provider'] ?? 'paystack',
      email: json['email'],
      cardLast4: json['card_last4'],
      cardBrand: json['card_brand'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      orderDetails: json['orders'],
    );
  }

  static TransactionStatus _parseTransactionStatus(String? status) {
    switch (status) {
      case 'success':
        return TransactionStatus.success;
      case 'failed':
        return TransactionStatus.failed;
      case 'refunded':
        return TransactionStatus.refunded;
      default:
        return TransactionStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'order_id': orderId,
      'reference': reference,
      'amount_cents': amountCents,
      'currency': currency,
      'status': status.name,
      'provider': provider,
      'email': email,
      'card_last4': cardLast4,
      'card_brand': cardBrand,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// ============================================================================
// PAYMENT STATISTICS
// ============================================================================

/// Aggregated payment statistics for a user
class PaymentStats {
  final int totalSpent;
  final int successfulPayments;
  final int failedPayments;
  final int pendingRefunds;

  PaymentStats({
    required this.totalSpent,
    required this.successfulPayments,
    required this.failedPayments,
    required this.pendingRefunds,
  });

  /// Get formatted total spent
  String get formattedTotalSpent {
    final amount = totalSpent / 100;
    return 'R ${amount.toStringAsFixed(2)}';
  }

  /// Get success rate percentage
  double get successRate {
    final total = successfulPayments + failedPayments;
    if (total == 0) return 100.0;
    return (successfulPayments / total) * 100;
  }

  factory PaymentStats.fromJson(Map<String, dynamic> json) {
    return PaymentStats(
      totalSpent: json['total_spent'] ?? 0,
      successfulPayments: json['successful_payments'] ?? 0,
      failedPayments: json['failed_payments'] ?? 0,
      pendingRefunds: json['pending_refunds'] ?? 0,
    );
  }
}

// ============================================================================
// SPLIT PAYMENT (FUTURE PHASE)
// ============================================================================

/// Represents a partial payment for split payments (future feature)
class SplitPayment {
  final String id;
  final String orderId;
  final int amountCents;
  final String paymentMethod;
  final TransactionStatus status;
  final DateTime createdAt;

  SplitPayment({
    required this.id,
    required this.orderId,
    required this.amountCents,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  String get formattedAmount {
    return 'R ${(amountCents / 100).toStringAsFixed(2)}';
  }

  factory SplitPayment.fromJson(Map<String, dynamic> json) {
    return SplitPayment(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      amountCents: json['amount_cents'] ?? 0,
      paymentMethod: json['payment_method'] ?? '',
      status: PaymentTransaction._parseTransactionStatus(json['status']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

/// Split payment plan configuration
class SplitPaymentPlan {
  final String orderId;
  final int totalAmountCents;
  final List<SplitPaymentInstallment> installments;

  SplitPaymentPlan({
    required this.orderId,
    required this.totalAmountCents,
    required this.installments,
  });

  int get paidAmount => installments
      .where((i) => i.isPaid)
      .fold(0, (sum, i) => sum + i.amountCents);

  int get remainingAmount => totalAmountCents - paidAmount;

  bool get isFullyPaid => remainingAmount <= 0;

  double get progressPercentage => (paidAmount / totalAmountCents) * 100;
}

/// Individual installment in a split payment plan
class SplitPaymentInstallment {
  final int amountCents;
  final DateTime dueDate;
  final bool isPaid;
  final String? paymentMethod;

  SplitPaymentInstallment({
    required this.amountCents,
    required this.dueDate,
    required this.isPaid,
    this.paymentMethod,
  });

  String get formattedAmount {
    return 'R ${(amountCents / 100).toStringAsFixed(2)}';
  }

  bool get isOverdue => !isPaid && DateTime.now().isAfter(dueDate);
}
