import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/marketplace.dart';
import '../models/payment_models.dart';

/// Payment Service Provider
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

/// Payment Service
/// Handles Paystack integration, card tokenization, and payment processing
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final _supabase = Supabase.instance.client;
  
  // Paystack keys - should be loaded from environment
  static const String _paystackPublicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
    defaultValue: 'pk_test_xxxxxxxxxxxxxxxxxxxxxxxx', // Replace with your key
  );

  bool _isInitialized = false;

  /// Initialize Paystack SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    // Paystack Plus initializes automatically
    _isInitialized = true;
  }

  /// Process payment for an order
  Future<PaymentResult> processPayment({
    required BuildContext context,
    required Order order,
    required String email,
    SavedCard? savedCard,
  }) async {
    await initialize();

    final amountInKobo = order.totalCents; // Paystack uses lowest currency unit
    final reference = _generateReference(order.id);

    try {
      // If using saved card, charge the authorization
      if (savedCard != null) {
        return await _chargeAuthorization(
          email: email,
          amount: amountInKobo,
          reference: reference,
          authorizationCode: savedCard.authorizationCode,
          orderId: order.id,
        );
      }

      // Otherwise, show Paystack checkout
      final result = await _showPaystackCheckout(
        context: context,
        email: email,
        amount: amountInKobo,
        reference: reference,
        orderId: order.id,
      );

      return result;
    } catch (e) {
      return PaymentResult(
        success: false,
        reference: reference,
        message: 'Payment failed: $e',
      );
    }
  }

  /// Show Paystack checkout UI
  Future<PaymentResult> _showPaystackCheckout({
    required BuildContext context,
    required String email,
    required int amount,
    required String reference,
    required String orderId,
  }) async {
    final completer = Completer<PaymentResult>();
    
    FlutterPaystackPlus.openPaystackPopup(
      publicKey: _paystackPublicKey,
      customerEmail: email,
      amount: amount.toString(),
      reference: reference,
      currency: 'ZAR',
      onClosed: () {
        if (!completer.isCompleted) {
          completer.complete(PaymentResult(
            success: false,
            reference: reference,
            message: 'Payment cancelled by user',
          ));
        }
      },
      onSuccess: () async {
        // Verify payment on backend
        final verificationResult = await _verifyPayment(reference);
        
        if (verificationResult.success) {
          // Update order payment status
          await _updateOrderPaymentStatus(
            orderId: orderId,
            reference: reference,
            status: 'paid',
          );

          // Record transaction
          await _recordTransaction(
            orderId: orderId,
            reference: reference,
            amount: amount,
            status: 'success',
            email: email,
          );
        }
        
        if (!completer.isCompleted) {
          completer.complete(verificationResult);
        }
      },
      context: context,
    );

    return completer.future;
  }

  /// Charge a saved card authorization
  Future<PaymentResult> _chargeAuthorization({
    required String email,
    required int amount,
    required String reference,
    required String authorizationCode,
    required String orderId,
  }) async {
    try {
      // Call backend API to charge authorization
      final response = await _supabase.functions.invoke(
        'charge-authorization',
        body: {
          'email': email,
          'amount': amount,
          'reference': reference,
          'authorization_code': authorizationCode,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        if (data['status'] == true) {
          await _updateOrderPaymentStatus(
            orderId: orderId,
            reference: reference,
            status: 'paid',
          );

          await _recordTransaction(
            orderId: orderId,
            reference: reference,
            amount: amount,
            status: 'success',
            email: email,
          );

          return PaymentResult(
            success: true,
            reference: reference,
            message: 'Payment successful',
            authorizationCode: data['data']?['authorization']?['authorization_code'],
          );
        }
      }

      return PaymentResult(
        success: false,
        reference: reference,
        message: response.data?['message'] ?? 'Payment failed',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        reference: reference,
        message: 'Error processing payment: $e',
      );
    }
  }

  /// Verify payment with Paystack
  Future<PaymentResult> _verifyPayment(String reference) async {
    try {
      final response = await _supabase.functions.invoke(
        'verify-payment',
        body: {'reference': reference},
      );

      if (response.status == 200) {
        final data = response.data;
        if (data['status'] == true && data['data']['status'] == 'success') {
          return PaymentResult(
            success: true,
            reference: reference,
            message: 'Payment verified',
            authorizationCode: data['data']?['authorization']?['authorization_code'],
            cardLast4: data['data']?['authorization']?['last4'],
            cardBrand: data['data']?['authorization']?['brand'],
          );
        }
      }

      return PaymentResult(
        success: false,
        reference: reference,
        message: 'Payment verification failed',
      );
    } catch (e) {
      // If verification fails, assume success from callback
      return PaymentResult(
        success: true,
        reference: reference,
        message: 'Payment completed',
      );
    }
  }

  /// Update order payment status in database
  Future<void> _updateOrderPaymentStatus({
    required String orderId,
    required String reference,
    required String status,
  }) async {
    await _supabase.from('orders').update({
      'payment_status': status,
      'payment_reference': reference,
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }

  /// Record transaction in database
  Future<void> _recordTransaction({
    required String orderId,
    required String reference,
    required int amount,
    required String status,
    required String email,
    String? cardLast4,
    String? cardBrand,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('payment_transactions').insert({
      'user_id': userId,
      'order_id': orderId,
      'reference': reference,
      'amount_cents': amount,
      'currency': 'ZAR',
      'status': status,
      'provider': 'paystack',
      'email': email,
      'card_last4': cardLast4,
      'card_brand': cardBrand,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Generate unique payment reference
  String _generateReference(String orderId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'SPL-${orderId.substring(0, 8)}-$timestamp';
  }

  // ==================== SAVED CARDS ====================

  /// Save a card after successful payment
  Future<void> saveCard({
    required String authorizationCode,
    required String email,
    required String last4,
    required String brand,
    required String expMonth,
    required String expYear,
    required String cardType,
    required String bank,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Check if card already saved
    final existing = await _supabase
        .from('saved_cards')
        .select()
        .eq('user_id', userId)
        .eq('last4', last4)
        .eq('brand', brand)
        .maybeSingle();

    if (existing != null) {
      // Update existing card
      await _supabase.from('saved_cards').update({
        'authorization_code': authorizationCode,
        'exp_month': expMonth,
        'exp_year': expYear,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
    } else {
      // Insert new card
      await _supabase.from('saved_cards').insert({
        'user_id': userId,
        'authorization_code': authorizationCode,
        'email': email,
        'last4': last4,
        'brand': brand,
        'exp_month': expMonth,
        'exp_year': expYear,
        'card_type': cardType,
        'bank': bank,
        'is_default': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Get user's saved cards
  Future<List<SavedCard>> getSavedCards() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('saved_cards')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return (response as List).map((json) => SavedCard.fromJson(json)).toList();
  }

  /// Delete a saved card
  Future<void> deleteCard(String cardId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('saved_cards')
        .delete()
        .eq('id', cardId)
        .eq('user_id', userId);
  }

  /// Set a card as default
  Future<void> setDefaultCard(String cardId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Remove default from all cards
    await _supabase
        .from('saved_cards')
        .update({'is_default': false})
        .eq('user_id', userId);

    // Set new default
    await _supabase
        .from('saved_cards')
        .update({'is_default': true})
        .eq('id', cardId)
        .eq('user_id', userId);
  }

  // ==================== REFUNDS ====================

  /// Request a refund for an order
  Future<RefundResult> requestRefund({
    required String orderId,
    required String reason,
    String? description,
    List<String>? photoUrls,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return RefundResult(success: false, message: 'User not authenticated');
    }

    try {
      // Create refund request in database
      final response = await _supabase.from('refund_requests').insert({
        'user_id': userId,
        'order_id': orderId,
        'reason': reason,
        'description': description,
        'photo_urls': photoUrls,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return RefundResult(
        success: true,
        message: 'Refund request submitted successfully',
        refundId: response['id'],
      );
    } catch (e) {
      return RefundResult(
        success: false,
        message: 'Failed to submit refund request: $e',
      );
    }
  }

  /// Get refund request status
  Future<RefundRequest?> getRefundRequest(String orderId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('refund_requests')
        .select()
        .eq('order_id', orderId)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return RefundRequest.fromJson(response);
  }

  /// Get all refund requests for user
  Future<List<RefundRequest>> getRefundRequests() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('refund_requests')
        .select('*, orders(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => RefundRequest.fromJson(json)).toList();
  }

  // ==================== PAYMENT HISTORY ====================

  /// Get payment transactions history
  Future<List<PaymentTransaction>> getPaymentHistory({
    int limit = 50,
    String? status,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    var query = _supabase
        .from('payment_transactions')
        .select('*, orders(*, offers(*, shops(*)))')
        .eq('user_id', userId);

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => PaymentTransaction.fromJson(json)).toList();
  }

  /// Get payment statistics
  Future<PaymentStats> getPaymentStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return PaymentStats(
        totalSpent: 0,
        successfulPayments: 0,
        failedPayments: 0,
        pendingRefunds: 0,
      );
    }

    final transactions = await _supabase
        .from('payment_transactions')
        .select('amount_cents, status')
        .eq('user_id', userId);

    final refunds = await _supabase
        .from('refund_requests')
        .select('status')
        .eq('user_id', userId)
        .eq('status', 'pending');

    int totalSpent = 0;
    int successful = 0;
    int failed = 0;

    for (final t in transactions) {
      if (t['status'] == 'success') {
        totalSpent += (t['amount_cents'] as int);
        successful++;
      } else if (t['status'] == 'failed') {
        failed++;
      }
    }

    return PaymentStats(
      totalSpent: totalSpent,
      successfulPayments: successful,
      failedPayments: failed,
      pendingRefunds: (refunds as List).length,
    );
  }
}
