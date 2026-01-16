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
  Future<Map<String, dynamic>> createPartRequest({
    required String mechanicId,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String partCategory,
    String? description,
    String? vin,
    String? engineNumber,
    List<String>? imageUrls,
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
      'image_urls': imageUrls,
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
  Future<List<Map<String, dynamic>>> getMechanicRequests(String mechanicId) async {
    final response = await _client
        .from(SupabaseConstants.partRequestsTable)
        .select()
        .eq('mechanic_id', mechanicId)
        .order('created_at', ascending: false);
    
    final requests = List<Map<String, dynamic>>.from(response);
    
    // Fetch offer counts and shop counts for each request
    for (var request in requests) {
      // Get offer count from offers table
      final offersResponse = await _client
          .from('offers')
          .select('id')
          .eq('request_id', request['id']);
      
      final offerCount = (offersResponse as List).length;
      request['offer_count'] = offerCount;
      
      // Get shop count from request_chats table (how many shops received this request)
      final chatsResponse = await _client
          .from('request_chats')
          .select('id, status')
          .eq('request_id', request['id']);
      
      final shopCount = (chatsResponse as List).length;
      final quotedCount = chatsResponse.where((c) => c['status'] == 'quoted').length;
      
      request['shop_count'] = shopCount;  // Total shops that received the request
      request['quoted_count'] = quotedCount;  // Shops that have sent quotes
      
      // Update status to 'offered' if there are offers/quotes and status is still pending
      if ((offerCount > 0 || quotedCount > 0) && request['status'] == 'pending') {
        request['status'] = 'offered';
        // Use quoted_count as offer_count if offers table is empty but quotes exist
        if (offerCount == 0 && quotedCount > 0) {
          request['offer_count'] = quotedCount;
        }
      }
    }
    
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
  /// 1. Updates offers.status to 'accepted'
  /// 2. Updates part_requests.status to 'accepted'  
  /// 3. Creates an order in the orders table
  /// 4. Rejects all other pending offers for this request
  /// 5. Sends notification to shop owner
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
    
    // Step 1: Update offer status to 'accepted' in the offers table
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
    
    // Get all request_chats for these requests with shop and request details
    final response = await _client
        .from('request_chats')
        .select('''
          *,
          shops:shop_id(id, name, phone, suburb, rating),
          part_requests:request_id(id, vehicle_make, vehicle_model, vehicle_year, part_category, status)
        ''')
        .inFilter('request_id', requestIds)
        .order('updated_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
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
  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    final response = await _client
        .from(SupabaseConstants.conversationsTable)
        .select('*, shops(*), profiles(*), messages(text, sent_at)')
        .or('mechanic_id.eq.$userId,shop_id.eq.$userId')
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
}
