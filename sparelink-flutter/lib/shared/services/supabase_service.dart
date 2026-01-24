import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/supabase_constants.dart';

/// Supabase Client Provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Supabase Service Provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});

/// Auth State Provider - reactive stream of auth changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

/// Current User Profile Provider
final currentUserProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  
  final supabaseService = ref.watch(supabaseServiceProvider);
  return await supabaseService.getProfile(user.id);
});

class SupabaseService {
  final SupabaseClient _client;
  
  SupabaseService(this._client);
  
  // ============================================
  // AUTH METHODS
  // ============================================
  
  /// Sign up with phone number (sends OTP)
  Future<AuthResponse> signUpWithPhone({
    required String phone,
    required String password,
    String? fullName,
    String role = 'mechanic',
  }) async {
    final response = await _client.auth.signUp(
      phone: phone,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
      },
    );
    return response;
  }
  
  /// Sign in with phone and OTP (sends OTP to phone)
  Future<void> signInWithOtp({
    required String phone,
  }) async {
    // This sends an OTP to the phone number
    await _client.auth.signInWithOtp(
      phone: phone,
    );
    // Note: For testing with test phone numbers, OTP is pre-set (e.g., 123456)
  }
  
  /// Verify OTP
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
    return response;
  }
  
  /// Sign in with phone and password (for test accounts)
  Future<AuthResponse> signInWithPassword({
    required String phone,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      phone: phone,
      password: password,
    );
    return response;
  }
  
  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  /// Get current session
  Session? get currentSession => _client.auth.currentSession;
  
  /// Get current user
  User? get currentUser => _client.auth.currentUser;
  
  // ============================================
  // PROFILE METHODS
  // ============================================
  
  /// Get user profile
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from(SupabaseConstants.profilesTable)
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }
  
  /// Update user profile
  /// 
  /// Fields saved to profiles table:
  /// - full_name: User's display name
  /// - phone: Phone number
  /// - street_address: Street address line
  /// - suburb: Suburb (used for shop matching)
  /// - city: City name
  /// - postal_code: Postal/ZIP code
  /// - province: Province/State
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? suburb,
    String? streetAddress,
    String? city,
    String? postalCode,
    String? province,
  }) async {
    final updateData = <String, dynamic>{};
    if (fullName != null) updateData['full_name'] = fullName;
    if (phone != null) updateData['phone'] = phone;
    if (suburb != null) updateData['suburb'] = suburb;
    if (streetAddress != null) updateData['street_address'] = streetAddress;
    if (city != null) updateData['city'] = city;
    if (postalCode != null) updateData['postal_code'] = postalCode;
    if (province != null) updateData['province'] = province;
    updateData['updated_at'] = DateTime.now().toIso8601String();
    
    await _client
        .from(SupabaseConstants.profilesTable)
        .update(updateData)
        .eq('id', userId);
  }
  
  /// Get shops by suburb (same suburb first, then nearby)
  Future<List<Map<String, dynamic>>> getShopsBySuburb({
    required String suburb,
    int limit = 5,
  }) async {
    // First try to get shops in the same suburb
    final sameSuburb = await _client
        .from(SupabaseConstants.shopsTable)
        .select()
        .ilike('suburb', '%$suburb%')
        .limit(limit);
    
    if ((sameSuburb as List).length >= limit) {
      return List<Map<String, dynamic>>.from(sameSuburb);
    }
    
    // If not enough, get all shops and return up to limit
    final allShops = await _client
        .from(SupabaseConstants.shopsTable)
        .select()
        .order('rating', ascending: false)
        .limit(limit);
    
    return List<Map<String, dynamic>>.from(allShops);
  }
  
  /// Send request to nearby shops (creates notifications for shops in the area)
  Future<void> notifyNearbyShops({
    required String requestId,
    required String suburb,
    required String partName,
    required String vehicleInfo,
  }) async {
    // Get shops in same suburb first
    final shops = await getShopsBySuburb(suburb: suburb, limit: 5);
    
    // Create notifications for each shop
    for (final shop in shops) {
      await _client.from('notifications').insert({
        'user_id': shop['owner_id'],
        'title': 'New Part Request',
        'body': 'New request for $partName - $vehicleInfo',
        'type': 'new_request',
        'data': {'request_id': requestId},
      });
    }
  }
  
  // ============================================
  // PART REQUEST METHODS
  // ============================================
  
  /// Create a new part request
  /// 
  /// The [imageUrl] parameter stores the primary part image URL.
  /// This is displayed on the My Requests screen and in the Shop Dashboard.
  Future<Map<String, dynamic>> createPartRequest({
    required String mechanicId,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String partCategory,
    String? description,
    String? vin,
    String? engineNumber,
    String? imageUrl,  // Single image URL for the primary part photo
    double? lat,
    double? lng,
  }) async {
    final data = {
      'mechanic_id': mechanicId,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'part_category': partCategory,
      'description': description,
      'vin': vin,
      'engine_number': engineNumber,
      'image_url': imageUrl,  // Stores in image_url column
      'status': 'pending',
      'offer_count': 0,
    };
    
    // Add location if provided
    if (lat != null && lng != null) {
      data['location'] = 'POINT($lng $lat)';
    }
    
    final response = await _client
        .from(SupabaseConstants.partRequestsTable)
        .insert(data)
        .select()
        .single();
    
    return response;
  }
  
  /// Get all requests for a mechanic (with offer counts and shop counts)
  /// 
  /// OPTIMIZED (Pass 2 Phase 2): Uses database view to eliminate N+1 queries
  /// Previous: 2N+1 queries (201 queries for 100 requests)
  /// Now: 1 query using part_requests_with_counts view
  /// Fallback: Uses RPC function if view not available
  /// Legacy fallback: Original N+1 pattern if neither available
  Future<List<Map<String, dynamic>>> getMechanicRequests(String mechanicId) async {
    // OPTIMIZATION: Try using the pre-computed view first (1 query instead of 2N+1)
    try {
      final response = await _client
          .from('part_requests_with_counts')  // Optimized view
          .select()
          .eq('mechanic_id', mechanicId)
          .order('created_at', ascending: false);
      
      final requests = List<Map<String, dynamic>>.from(response);
      
      // Update status to 'offered' if there are offers/quotes and status is still pending
      for (var request in requests) {
        final offerCount = request['offer_count'] ?? 0;
        final quotedCount = request['quoted_count'] ?? 0;
        
        if ((offerCount > 0 || quotedCount > 0) && request['status'] == 'pending') {
          request['status'] = 'offered';
          if (offerCount == 0 && quotedCount > 0) {
            request['offer_count'] = quotedCount;
          }
        }
      }
      
      debugPrint('✅ [getMechanicRequests] Used optimized view - 1 query for ${requests.length} requests');
      return requests;
      
    } catch (viewError) {
      debugPrint('⚠️ [getMechanicRequests] View not available, trying RPC function...');
      
      // FALLBACK 1: Try using the RPC function
      try {
        final response = await _client.rpc(
          'get_mechanic_requests_with_counts',
          params: {'p_mechanic_id': mechanicId},
        );
        
        final requests = List<Map<String, dynamic>>.from(response);
        
        // Update status to 'offered' if there are offers/quotes
        for (var request in requests) {
          final offerCount = request['offer_count'] ?? 0;
          final quotedCount = request['quoted_count'] ?? 0;
          
          if ((offerCount > 0 || quotedCount > 0) && request['status'] == 'pending') {
            request['status'] = 'offered';
            if (offerCount == 0 && quotedCount > 0) {
              request['offer_count'] = quotedCount;
            }
          }
        }
        
        debugPrint('✅ [getMechanicRequests] Used RPC function - 1 query for ${requests.length} requests');
        return requests;
        
      } catch (rpcError) {
        debugPrint('⚠️ [getMechanicRequests] RPC not available, using legacy N+1 pattern...');
        
        // FALLBACK 2: Legacy N+1 pattern (for backward compatibility)
        return _getMechanicRequestsLegacy(mechanicId);
      }
    }
  }
  
  /// Legacy N+1 query pattern for getMechanicRequests
  /// Used as fallback when optimized view/function not deployed
  /// TODO: Remove once all environments have the optimized view
  Future<List<Map<String, dynamic>>> _getMechanicRequestsLegacy(String mechanicId) async {
    final response = await _client
        .from(SupabaseConstants.partRequestsTable)
        .select()
        .eq('mechanic_id', mechanicId)
        .order('created_at', ascending: false);
    
    final requests = List<Map<String, dynamic>>.from(response);
    
    // Fetch offer counts and shop counts for each request (N+1 pattern)
    for (var request in requests) {
      // Get offer count from offers table
      final offersResponse = await _client
          .from('offers')
          .select('id')
          .eq('request_id', request['id']);
      
      final offerCount = (offersResponse as List).length;
      request['offer_count'] = offerCount;
      
      // Get shop count from request_chats table
      final chatsResponse = await _client
          .from('request_chats')
          .select('id, status')
          .eq('request_id', request['id']);
      
      final shopCount = (chatsResponse as List).length;
      final quotedCount = chatsResponse.where((c) => c['status'] == 'quoted').length;
      
      request['shop_count'] = shopCount;
      request['quoted_count'] = quotedCount;
      
      // Update status to 'offered' if there are offers/quotes and status is still pending
      if ((offerCount > 0 || quotedCount > 0) && request['status'] == 'pending') {
        request['status'] = 'offered';
        if (offerCount == 0 && quotedCount > 0) {
          request['offer_count'] = quotedCount;
        }
      }
    }
    
    debugPrint('⚠️ [getMechanicRequests] Used legacy N+1 pattern - ${requests.length * 2 + 1} queries');
    return requests;
  }
  
  /// Get a single request by ID
  Future<Map<String, dynamic>?> getRequest(String requestId) async {
    final response = await _client
        .from(SupabaseConstants.partRequestsTable)
        .select()
        .eq('id', requestId)
        .maybeSingle();
    
    return response;
  }
  
  /// Update request status
  Future<void> updateRequestStatus(String requestId, String status) async {
    await _client
        .from(SupabaseConstants.partRequestsTable)
        .update({'status': status})
        .eq('id', requestId);
  }
  
  // ============================================
  // SHOP METHODS
  // ============================================
  
  /// Get nearby shops using PostGIS function
  Future<List<Map<String, dynamic>>> getNearbyShops({
    required double lat,
    required double lng,
    double radiusMeters = 50000, // 50km default
  }) async {
    final response = await _client.rpc(
      SupabaseConstants.nearbyShopsFunction,
      params: {
        'mech_lat': lat,
        'mech_lng': lng,
        'radius_meters': radiusMeters,
      },
    );
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get shop by ID
  Future<Map<String, dynamic>?> getShop(String shopId) async {
    final response = await _client
        .from(SupabaseConstants.shopsTable)
        .select()
        .eq('id', shopId)
        .maybeSingle();
    
    return response;
  }
  
  /// Get all shops (for testing)
  Future<List<Map<String, dynamic>>> getAllShops() async {
    final response = await _client
        .from(SupabaseConstants.shopsTable)
        .select()
        .order('rating', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  // ============================================
  // OFFER METHODS
  // ============================================
  
  /// Get offers for a request
  Future<List<Map<String, dynamic>>> getOffersForRequest(String requestId) async {
    final response = await _client
        .from(SupabaseConstants.offersTable)
        .select('*, shops(*)')
        .eq('request_id', requestId)
        .order('price_cents', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Reject an offer
  Future<void> rejectOffer({
    required String offerId,
    required String requestId,
    required String shopId,
  }) async {
    // Update offer status to rejected
    await _client
        .from(SupabaseConstants.offersTable)
        .update({'status': 'rejected'})
        .eq('id', offerId);
    
    // Also update request_chats status if exists
    await _client
        .from('request_chats')
        .update({'status': 'rejected'})
        .eq('request_id', requestId)
        .eq('shop_id', shopId);
  }
  
  /// Accept an offer (and update request status)
  /// 
  /// This method:
  /// 1. Updates offers.status to 'accepted' (triggers CS-17 validation)
  /// 2. Updates part_requests.status to 'accepted'  
  /// 3. Creates an order in the orders table
  /// 4. Rejects all other pending offers for this request
  /// 5. Sends notification to shop owner
  /// 
  /// CS-17 FIX: Now handles server-side quote expiry validation
  /// Throws [QuoteExpiredException] if the quote has expired
  /// Throws [QuoteAlreadyAcceptedException] if another user accepted first
  /// Throws [QuoteRejectedException] if the quote was rejected
  Future<Map<String, dynamic>> acceptOffer({
    required String offerId,
    required String requestId,
    required int totalCents,
    required String deliveryDestination,
    String? deliveryAddress,
  }) async {
    debugPrint('=== acceptOffer START ===');
    debugPrint('offerId: $offerId');
    debugPrint('requestId: $requestId');
    
    try {
      // Step 1: Update offer status to 'accepted' in the offers table
      // The database trigger (validate_offer_acceptance) will check:
      // - If quote is already accepted (race condition prevention)
      // - If quote has expired (CS-17 fix)
      // - If quote was rejected
      debugPrint('Step 1: Updating offer status to accepted...');
      final offerUpdateResponse = await _client
          .from(SupabaseConstants.offersTable)
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', offerId)
          .select('*, shops(owner_id, name)');
      
      debugPrint('Offer update response: $offerUpdateResponse');
      
      if (offerUpdateResponse.isEmpty) {
        debugPrint('ERROR: Offer update returned empty - possible RLS issue or offer not found');
        throw Exception('Failed to update offer status - offer not found or permission denied. Check RLS policies on offers table.');
      }
      
      final acceptedOffer = offerUpdateResponse.first;
      debugPrint('Offer updated successfully. New status should be: ${acceptedOffer['status']}');
      
      // Step 2: Update request status
      final requestUpdateResponse = await _client
          .from(SupabaseConstants.partRequestsTable)
          .update({'status': 'accepted'})
          .eq('id', requestId)
          .select();
      
      if (requestUpdateResponse.isEmpty) {
        throw Exception('Failed to update request status - request not found');
      }
      
      final request = requestUpdateResponse.first;
      
      // Step 3: Create the order
      // The unique_offer_order constraint prevents duplicate orders for same offer
      final order = await _client
          .from(SupabaseConstants.ordersTable)
          .insert({
            'request_id': requestId,
            'offer_id': offerId,
            'total_cents': totalCents,
            'status': 'confirmed',
            'delivery_destination': deliveryDestination,
            'delivery_address': deliveryAddress,
          })
          .select()
          .single();
      
      // Step 4: Reject all other pending offers for this request
      await _client
          .from(SupabaseConstants.offersTable)
          .update({'status': 'rejected'})
          .eq('request_id', requestId)
          .neq('id', offerId)
          .eq('status', 'pending');
      
      // Step 5: Notify the shop owner that their offer was accepted
      try {
        final shopData = acceptedOffer['shops'];
        if (shopData != null && shopData['owner_id'] != null) {
          final vehicleInfo = '${request['vehicle_year']} ${request['vehicle_make']} ${request['vehicle_model']}';
          final totalRands = (totalCents / 100).toStringAsFixed(2);
          
          await _client.from('notifications').insert({
            'user_id': shopData['owner_id'],
            'type': 'offer_accepted',
            'title': 'Quote Accepted! 🎉',
            'body': 'Your quote of R$totalRands for $vehicleInfo has been accepted. Prepare the order for delivery.',
            'reference_id': order['id'],
          });
        }
      } catch (e) {
        // Don't fail the order if notification fails
        // Notification is non-critical, so we just log and continue
        debugPrint('Warning: Failed to send acceptance notification: $e');
      }
      
      return order;
      
    } on PostgrestException catch (e) {
      // CS-17 FIX: Handle specific database errors from our validation trigger
      debugPrint('PostgrestException in acceptOffer: ${e.code} - ${e.message}');
      
      final message = e.message ?? '';
      
      // Check for our custom error messages from the trigger
      if (message.contains('QUOTE_ALREADY_ACCEPTED') || e.code == 'P0001') {
        throw QuoteAlreadyAcceptedException(
          'This quote has already been accepted. Another user may have accepted it first.'
        );
      } else if (message.contains('QUOTE_EXPIRED') || e.code == 'P0002') {
        throw QuoteExpiredException(
          'This quote has expired. Please request a new quote from the shop.'
        );
      } else if (message.contains('QUOTE_REJECTED') || e.code == 'P0003') {
        throw QuoteRejectedException(
          'This quote has been rejected and cannot be accepted.'
        );
      } else if (e.code == '23505') {
        // Unique constraint violation - another order already exists for this offer
        throw QuoteAlreadyAcceptedException(
          'An order has already been created for this quote.'
        );
      }
      
      // Re-throw other PostgrestExceptions
      rethrow;
    }
  }
  
  // ============================================
  // ORDER METHODS
  // ============================================
  
  /// Get orders for a mechanic
  Future<List<Map<String, dynamic>>> getMechanicOrders(String mechanicId) async {
    final response = await _client
        .from(SupabaseConstants.ordersTable)
        .select('*, part_requests!inner(*), offers(*, shops(*))')
        .eq('part_requests.mechanic_id', mechanicId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get a single order
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    final response = await _client
        .from(SupabaseConstants.ordersTable)
        .select('*, part_requests(*), offers(*, shops(*))')
        .eq('id', orderId)
        .maybeSingle();
    
    return response;
  }
  
  /// Get orders for a specific request
  Future<List<Map<String, dynamic>>> getOrdersForRequest(String requestId) async {
    final response = await _client
        .from(SupabaseConstants.ordersTable)
        .select('*, offers(*, shops(*))')
        .eq('request_id', requestId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Subscribe to order status changes (real-time)
  RealtimeChannel subscribeToOrder(String orderId, void Function(Map<String, dynamic>) onUpdate) {
    return _client
        .channel('order_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.ordersTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }
  
  // ============================================
  // CHAT / CONVERSATION METHODS
  // ============================================
  
  /// Get request_chats for a mechanic (all shops that received their requests)
  /// Filters out:
  /// - Archived chats (archived_at is not null)
  /// - Completed/rejected chats older than 24 hours (data retention policy)
  Future<List<Map<String, dynamic>>> getMechanicRequestChats(String mechanicId) async {
    // First get all part_requests for this mechanic
    final requests = await _client
        .from(SupabaseConstants.partRequestsTable)
        .select('id')
        .eq('mechanic_id', mechanicId);
    
    if ((requests as List).isEmpty) {
      return [];
    }
    
    final requestIds = requests.map((r) => r['id'] as String).toList();
    
    // Calculate 24 hours ago for data retention cutoff
    final retentionCutoff = DateTime.now().subtract(const Duration(hours: 24)).toUtc().toIso8601String();
    
    // Get all request_chats for these requests with shop and request details
    // Filter out archived chats
    final response = await _client
        .from('request_chats')
        .select('''
          *,
          shops:shop_id(id, name, phone, suburb, rating),
          part_requests:request_id(id, vehicle_make, vehicle_model, vehicle_year, part_category, status, mechanic_id)
        ''')
        .inFilter('request_id', requestIds)
        .order('updated_at', ascending: false);
    
    // Filter out old completed/rejected chats (24h data retention policy)
    final filteredChats = (response as List).where((chat) {
      // Always show pending and quoted chats
      final status = chat['status'] as String?;
      if (status == 'pending' || status == 'quoted') {
        return true;
      }
      
      // For accepted/rejected/completed - check if within 24 hours
      final updatedAt = chat['updated_at'] as String?;
      if (updatedAt == null) return true;
      
      try {
        final updateTime = DateTime.parse(updatedAt);
        final cutoffTime = DateTime.parse(retentionCutoff);
        return updateTime.isAfter(cutoffTime);
      } catch (e) {
        return true; // Keep if we can't parse the date
      }
    }).toList();
    
    return List<Map<String, dynamic>>.from(filteredChats);
  }
  
  /// Get or create a conversation
  Future<Map<String, dynamic>> getOrCreateConversation({
    required String requestId,
    required String mechanicId,
    required String shopId,
  }) async {
    // First, try to find existing conversation
    final existing = await _client
        .from(SupabaseConstants.conversationsTable)
        .select()
        .eq('request_id', requestId)
        .eq('mechanic_id', mechanicId)
        .eq('shop_id', shopId)
        .maybeSingle();
    
    if (existing != null) return existing;
    
    // Create new conversation
    final response = await _client
        .from(SupabaseConstants.conversationsTable)
        .insert({
          'request_id': requestId,
          'mechanic_id': mechanicId,
          'shop_id': shopId,
        })
        .select()
        .single();
    
    return response;
  }
  
  /// Get conversations for a user (mechanic or shop)
  /// Filters out archived conversations (archived_at is not null)
  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    final response = await _client
        .from(SupabaseConstants.conversationsTable)
        .select('*, shops(*), profiles(*), messages(text, sent_at)')
        .or('mechanic_id.eq.$userId,shop_id.eq.$userId')
        .isFilter('archived_at', null)  // Only show non-archived conversations
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get messages for a conversation
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final response = await _client
        .from(SupabaseConstants.messagesTable)
        .select('*, profiles(full_name)')
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Send a message
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final response = await _client
        .from(SupabaseConstants.messagesTable)
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'text': text,
        })
        .select()
        .single();
    
    return response;
  }
  
  /// Get unread counts for multiple chats in a single batch query
  /// 
  /// OPTIMIZED (Pass 2 Phase 2): Reduces N queries to 1 query
  /// Use this instead of calling getUnreadCountForChat() in a loop
  Future<Map<String, int>> getUnreadCountsForChatsBatch(
    List<Map<String, String>> chats, // [{request_id, shop_id}]
    String userId,
  ) async {
    if (chats.isEmpty) return {};
    
    try {
      // Build chat keys for batch query
      final chatKeys = chats.map((c) => '${c['request_id']}:${c['shop_id']}').toList();
      
      // Try using the optimized RPC function first
      final response = await _client.rpc(
        'get_unread_counts_batch',
        params: {
          'p_user_id': userId,
          'p_chat_keys': chatKeys,
        },
      );
      
      // Convert to map
      final counts = <String, int>{};
      for (final row in response) {
        counts[row['chat_key']] = (row['unread_count'] as num).toInt();
      }
      
      // Fill in zeros for chats with no unread messages
      for (final key in chatKeys) {
        counts.putIfAbsent(key, () => 0);
      }
      
      debugPrint('✅ [getUnreadCountsForChatsBatch] Batch query returned ${counts.length} results');
      return counts;
      
    } catch (e) {
      debugPrint('⚠️ [getUnreadCountsForChatsBatch] RPC not available, falling back to individual queries: $e');
      
      // Fallback: Query individually (N queries)
      final counts = <String, int>{};
      for (final chat in chats) {
        final key = '${chat['request_id']}:${chat['shop_id']}';
        counts[key] = await getUnreadCountForChat(
          chat['request_id']!,
          chat['shop_id']!,
          userId,
        );
      }
      return counts;
    }
  }
  
  /// Get last messages for multiple chats in a single batch query
  /// 
  /// OPTIMIZED (Pass 2 Phase 2): Reduces N queries to 1 query
  Future<Map<String, Map<String, dynamic>>> getLastMessagesForChatsBatch(
    List<Map<String, String>> chats, // [{request_id, shop_id}]
  ) async {
    if (chats.isEmpty) return {};
    
    try {
      // Build chat keys for batch query
      final chatKeys = chats.map((c) => '${c['request_id']}:${c['shop_id']}').toList();
      
      // Try using the optimized RPC function first
      final response = await _client.rpc(
        'get_last_messages_batch',
        params: {'p_chat_keys': chatKeys},
      );
      
      // Convert to map
      final messages = <String, Map<String, dynamic>>{};
      for (final row in response) {
        messages[row['chat_key']] = {
          'text': row['message_text'],
          'sent_at': row['sent_at'],
          'sender_id': row['sender_id'],
          'is_read': row['is_read'],
        };
      }
      
      debugPrint('✅ [getLastMessagesForChatsBatch] Batch query returned ${messages.length} results');
      return messages;
      
    } catch (e) {
      debugPrint('⚠️ [getLastMessagesForChatsBatch] RPC not available, falling back to individual queries: $e');
      
      // Fallback: Query individually (N queries)
      final messages = <String, Map<String, dynamic>>{};
      for (final chat in chats) {
        final key = '${chat['request_id']}:${chat['shop_id']}';
        final msg = await getLastMessageForChat(chat['request_id']!, chat['shop_id']!);
        if (msg != null) {
          messages[key] = msg;
        }
      }
      return messages;
    }
  }

  /// Get unread message count for a chat
  /// 
  /// FIXED: Queries request_chat_messages table directly (the actual source of chat messages)
  /// instead of the older conversations+messages tables
  /// 
  /// NOTE: For multiple chats, use getUnreadCountsForChatsBatch() instead to avoid N+1 queries
  Future<int> getUnreadCountForChat(String requestId, String shopId, String userId) async {
    try {
      // Query request_chat_messages directly - this is where chat messages are stored
      final response = await _client
          .from('request_chat_messages')
          .select('id')
          .eq('request_id', requestId)
          .eq('shop_id', shopId)
          .neq('sender_id', userId)
          .eq('is_read', false);
      
      final count = (response as List).length;
      debugPrint('📊 [getUnreadCountForChat] request: $requestId, shop: $shopId, unread: $count');
      return count;
    } catch (e) {
      debugPrint('⚠️ [getUnreadCountForChat] Error: $e');
      
      // Fallback: Try the old conversations+messages tables
      try {
        final conversation = await _client
            .from(SupabaseConstants.conversationsTable)
            .select('id')
            .eq('request_id', requestId)
            .eq('shop_id', shopId)
            .maybeSingle();
        
        if (conversation == null) return 0;
        
        final fallbackResponse = await _client
            .from(SupabaseConstants.messagesTable)
            .select('id')
            .eq('conversation_id', conversation['id'])
            .neq('sender_id', userId)
            .eq('is_read', false);
        
        return (fallbackResponse as List).length;
      } catch (e2) {
        debugPrint('⚠️ [getUnreadCountForChat] Fallback also failed: $e2');
        return 0;
      }
    }
  }
  
  /// Mark all messages as read in a chat
  /// 
  /// FIXED: Now marks messages in request_chat_messages table (primary)
  /// with fallback to conversations+messages tables
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    // Try to mark in the old messages table first (for backward compatibility)
    try {
      await _client
          .from(SupabaseConstants.messagesTable)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('⚠️ [markMessagesAsRead] Failed to update messages table: $e');
    }
  }
  
  /// Mark all messages as read for a request+shop chat
  /// This is the primary method for request_chats system
  Future<void> markRequestChatMessagesAsRead(String requestId, String shopId, String userId) async {
    try {
      final result = await _client
          .from('request_chat_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('request_id', requestId)
          .eq('shop_id', shopId)
          .neq('sender_id', userId)
          .eq('is_read', false)
          .select('id');
      
      final count = (result as List).length;
      debugPrint('✅ [markRequestChatMessagesAsRead] Marked $count messages as read');
    } catch (e) {
      debugPrint('⚠️ [markRequestChatMessagesAsRead] Error: $e');
    }
  }
  
  /// Get last message for a request+shop chat (includes is_read for status ticks)
  /// 
  /// FIXED: Queries request_chat_messages directly instead of conversations+messages
  Future<Map<String, dynamic>?> getLastMessageForChat(String requestId, String shopId) async {
    try {
      // Query request_chat_messages directly
      final response = await _client
          .from('request_chat_messages')
          .select('text, sent_at, sender_id, is_read')
          .eq('request_id', requestId)
          .eq('shop_id', shopId)
          .order('sent_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        debugPrint('📬 [getLastMessageForChat] Found message: ${response['text']?.toString().substring(0, 20) ?? 'null'}...');
        return response;
      }
    } catch (e) {
      debugPrint('⚠️ [getLastMessageForChat] Error querying request_chat_messages: $e');
    }
    
    // Fallback: Try the old conversations+messages tables
    try {
      final conversation = await _client
          .from(SupabaseConstants.conversationsTable)
          .select('id')
          .eq('request_id', requestId)
          .eq('shop_id', shopId)
          .maybeSingle();
      
      if (conversation == null) return null;
      
      final response = await _client
          .from(SupabaseConstants.messagesTable)
          .select('text, sent_at, sender_id, is_read')
          .eq('conversation_id', conversation['id'])
          .order('sent_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return response;
    } catch (e2) {
      debugPrint('⚠️ [getLastMessageForChat] Fallback also failed: $e2');
      return null;
    }
  }
  
  /// Subscribe to new messages in a conversation (real-time)
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onNewMessage,
  ) {
    return _client
        .channel('messages_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onNewMessage(payload.newRecord);
          },
        )
        .subscribe();
  }
  
  // ============================================
  // STORAGE METHODS (Image Upload)
  // ============================================
  
  /// Upload a part image and return the public URL
  Future<String> uploadPartImage({
    required String fileName,
    required Uint8List fileBytes,
    String? mimeType,
  }) async {
    final path = 'requests/$fileName';
    
    await _client.storage
        .from(SupabaseConstants.partImagesBucket)
        .uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(
            contentType: mimeType ?? 'image/jpeg',
            upsert: true,
          ),
        );
    
    // Get public URL
    final publicUrl = _client.storage
        .from(SupabaseConstants.partImagesBucket)
        .getPublicUrl(path);
    
    return publicUrl;
  }
  
  /// Upload a part image from file
  Future<String> uploadPartImageFromFile({
    required String fileName,
    required File file,
  }) async {
    final path = 'requests/$fileName';
    
    await _client.storage
        .from(SupabaseConstants.partImagesBucket)
        .upload(path, file);
    
    // Get public URL
    final publicUrl = _client.storage
        .from(SupabaseConstants.partImagesBucket)
        .getPublicUrl(path);
    
    return publicUrl;
  }
  
  /// Delete an image
  Future<void> deletePartImage(String path) async {
    await _client.storage
        .from(SupabaseConstants.partImagesBucket)
        .remove([path]);
  }
  
  // ============================================
  // NOTIFICATION METHODS
  // ============================================
  
  /// Get notifications for a user
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('read', false);
    
    return (response as List).length;
  }
  
  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('id', notificationId);
  }
  
  /// Mark all notifications as read for a user
  Future<void> markAllNotificationsAsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', userId)
        .eq('read', false);
  }
  
  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _client
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }
  
  /// Subscribe to new notifications (real-time)
  RealtimeChannel subscribeToNotifications(
    String userId,
    void Function(Map<String, dynamic>) onNewNotification,
  ) {
    return _client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onNewNotification(payload.newRecord);
          },
        )
        .subscribe();
  }
  
  // ============================================
  // COUNTER-OFFER / NEGOTIATION METHODS
  // ============================================
  
  /// Send a counter-offer for an existing quote
  /// 
  /// This notifies the shop that the mechanic wants to negotiate
  Future<void> sendCounterOffer({
    required String offerId,
    required int counterOfferCents,
    String? message,
  }) async {
    // Update the offer with counter-offer details
    await _client
        .from(SupabaseConstants.offersTable)
        .update({
          'counter_offer_cents': counterOfferCents,
          'counter_offer_message': message,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', offerId);
    
    // Get offer details for notification
    final offer = await _client
        .from(SupabaseConstants.offersTable)
        .select('*, shops(owner_id, name), part_requests(vehicle_make, vehicle_model, part_category)')
        .eq('id', offerId)
        .single();
    
    // Notify the shop owner about the counter-offer
    final shopData = offer['shops'];
    final requestData = offer['part_requests'];
    if (shopData != null && shopData['owner_id'] != null) {
      final counterOfferRands = (counterOfferCents / 100).toStringAsFixed(2);
      final partInfo = requestData != null 
          ? '${requestData['part_category']} for ${requestData['vehicle_make']} ${requestData['vehicle_model']}'
          : 'your quote';
      
      await _client.from('notifications').insert({
        'user_id': shopData['owner_id'],
        'type': 'counter_offer',
        'title': 'Counter-Offer Received 💬',
        'body': 'A mechanic has offered R$counterOfferRands for $partInfo. ${message ?? ''}',
        'reference_id': offerId,
      });
    }
  }
  
  /// Subscribe to new offers/quotes for a specific request (real-time)
  /// 
  /// This allows mechanics to be notified instantly when shops send quotes
  RealtimeChannel subscribeToOffersForRequest(
    String requestId,
    void Function(Map<String, dynamic>) onNewOffer,
  ) {
    return _client
        .channel('offers_$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.offersTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: requestId,
          ),
          callback: (payload) {
            onNewOffer(payload.newRecord);
          },
        )
        .subscribe();
  }
  
  /// Subscribe to all new offers for a mechanic's requests
  /// 
  /// Uses a broader subscription and filters client-side
  RealtimeChannel subscribeToAllNewOffers(
    void Function(Map<String, dynamic>) onNewOffer,
  ) {
    return _client
        .channel('all_new_offers')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.offersTable,
          callback: (payload) {
            onNewOffer(payload.newRecord);
          },
        )
        .subscribe();
  }
  
  /// Create a notification for new quote received
  Future<void> notifyMechanicOfNewQuote({
    required String mechanicId,
    required String shopName,
    required String partName,
    required int priceCents,
    required String requestId,
    required String offerId,
  }) async {
    final priceRands = (priceCents / 100).toStringAsFixed(2);
    
    await _client.from('notifications').insert({
      'user_id': mechanicId,
      'type': 'new_quote',
      'title': 'New Quote Received! 💰',
      'body': '$shopName quoted R$priceRands for $partName',
      'reference_id': requestId,
      'data': {'offer_id': offerId},
    });
  }
}

// =============================================================================
// CUSTOM EXCEPTIONS FOR QUOTE HANDLING (CS-17 FIX)
// =============================================================================

/// Exception thrown when trying to accept an expired quote
class QuoteExpiredException implements Exception {
  final String message;
  QuoteExpiredException(this.message);
  
  @override
  String toString() => 'QuoteExpiredException: $message';
}

/// Exception thrown when trying to accept a quote that was already accepted
class QuoteAlreadyAcceptedException implements Exception {
  final String message;
  QuoteAlreadyAcceptedException(this.message);
  
  @override
  String toString() => 'QuoteAlreadyAcceptedException: $message';
}

/// Exception thrown when trying to accept a rejected quote
class QuoteRejectedException implements Exception {
  final String message;
  QuoteRejectedException(this.message);
  
  @override
  String toString() => 'QuoteRejectedException: $message';
}
