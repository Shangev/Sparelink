import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../../core/constants/api_constants.dart';
import 'storage_service.dart';

/// Dio HTTP Client Provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );
  
  // Add JWT Token Interceptor
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Get token from secure storage
        final token = await ref.read(storageServiceProvider).getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 Unauthorized - logout user
        if (error.response?.statusCode == 401) {
          await ref.read(storageServiceProvider).deleteToken();
          // TODO: Navigate to login screen
        }
        handler.next(error);
      },
    ),
  );
  
  // Add Logger (only in debug mode)
  dio.interceptors.add(
    PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
      maxWidth: 90,
    ),
  );
  
  return dio;
});

/// API Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio);
});

class ApiService {
  final Dio _dio;
  
  ApiService(this._dio);
  
  // ============================================
  // AUTH ENDPOINTS
  // ============================================
  
  /// Register new user
  Future<Map<String, dynamic>> register({
    required String role,
    required String name,
    required String phone,
    String? email,
    String? workshopName,
  }) async {
    final response = await _dio.post(
      ApiConstants.authRegister,
      data: {
        'role': role,
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
        if (workshopName != null) 'workshopName': workshopName,
      },
    );
    return response.data;
  }
  
  /// Login user
  Future<Map<String, dynamic>> login({
    required String phone,
  }) async {
    final response = await _dio.post(
      ApiConstants.authLogin,
      data: {'phone': phone},
    );
    return response.data;
  }
  
  // ============================================
  // REQUEST ENDPOINTS
  // ============================================
  
  /// Create new request
  Future<Map<String, dynamic>> createRequest({
    required String mechanicId,
    required String make,
    required String model,
    required int year,
    required String partName,
    String? description,
    List<String>? imagesBase64,
    double? lat,
    double? lng,
  }) async {
    final response = await _dio.post(
      ApiConstants.requests,
      data: {
        'mechanicId': mechanicId,
        'make': make,
        'model': model,
        'year': year,
        'partName': partName,
        if (description != null) 'description': description,
        if (imagesBase64 != null) 'imagesBase64': imagesBase64,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return response.data;
  }
  
  /// Get user requests
  Future<List<dynamic>> getUserRequests(String userId) async {
    final response = await _dio.get(
      ApiConstants.requestsByUser(userId),
    );
    return response.data;
  }
  
  /// Get offers for request
  Future<List<dynamic>> getRequestOffers(String requestId) async {
    final response = await _dio.get(
      ApiConstants.requestOffers(requestId),
    );
    return response.data;
  }
  
  // ============================================
  // SHOP ENDPOINTS
  // ============================================
  
  /// Get nearby shops
  Future<List<dynamic>> getNearbyShops({
    required double lat,
    required double lng,
    int radius = 20, // km
  }) async {
    final response = await _dio.get(
      ApiConstants.shopsNearby,
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius': radius,
      },
    );
    return response.data;
  }
  
  // ============================================
  // OFFER ENDPOINTS
  // ============================================
  
  /// Create offer
  Future<Map<String, dynamic>> createOffer({
    required String requestId,
    required String shopId,
    required int priceCents,
    required int deliveryFeeCents,
    required int etaMinutes,
    required String stockStatus,
    List<String>? partImagesBase64,
    String? message,
  }) async {
    final response = await _dio.post(
      ApiConstants.offers,
      data: {
        'requestId': requestId,
        'shopId': shopId,
        'priceCents': priceCents,
        'deliveryFeeCents': deliveryFeeCents,
        'etaMinutes': etaMinutes,
        'stockStatus': stockStatus,
        if (partImagesBase64 != null) 'partImagesBase64': partImagesBase64,
        if (message != null) 'message': message,
      },
    );
    return response.data;
  }
  
  // ============================================
  // CONVERSATION ENDPOINTS
  // ============================================
  
  /// Get conversations
  Future<List<dynamic>> getConversations(String userId) async {
    final response = await _dio.get(
      ApiConstants.conversations(userId),
    );
    return response.data;
  }
  
  // ============================================
  // UTILITY ENDPOINTS
  // ============================================
  
  /// Health check
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get(ApiConstants.health);
    return response.data;
  }
}
