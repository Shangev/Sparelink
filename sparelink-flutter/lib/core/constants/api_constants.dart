/// API Configuration for SpareLink Backend
class ApiConstants {
  // Base URL - Change to your backend URL
  static const String baseUrl = 'http://localhost:3333/api';
  
  // For physical devices and web, use your computer's IP:
  // static const String baseUrl = 'http://192.168.8.107:3333/api';
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
  
  // Auth Endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  
  // Request Endpoints
  static const String requests = '/requests';
  static String requestsByUser(String userId) => '/requests/user/$userId';
  static String requestOffers(String requestId) => '/requests/$requestId/offers';
  
  // Shop Endpoints
  static const String shopsNearby = '/shops/nearby';
  
  // Offer Endpoints
  static const String offers = '/offers';
  
  // Conversation Endpoints
  static String conversations(String userId) => '/conversations/$userId';
  
  // Utility Endpoints
  static const String health = '/health';
  static const String seedShops = '/seed/shops';
}
