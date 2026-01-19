import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/environment_config.dart';

/// Rate Limiter Service Provider
final rateLimiterProvider = Provider<RateLimiterService>((ref) {
  return RateLimiterService();
});

/// Rate limiting exception
class RateLimitExceededException implements Exception {
  final String message;
  final Duration retryAfter;
  
  RateLimitExceededException(this.message, this.retryAfter);
  
  @override
  String toString() => 'RateLimitExceededException: $message (retry after ${retryAfter.inSeconds}s)';
}

/// Rate Limiter Service
/// 
/// Implements a sliding window rate limiting algorithm to prevent API abuse.
/// This protects against:
/// - Brute force attacks on authentication
/// - Denial of service attempts
/// - Excessive API usage
/// 
/// Usage:
/// ```dart
/// final rateLimiter = ref.read(rateLimiterProvider);
/// 
/// // Check before making API call
/// if (rateLimiter.shouldAllowRequest('auth_login')) {
///   rateLimiter.recordRequest('auth_login');
///   // Make API call...
/// } else {
///   // Show rate limit error to user
/// }
/// ```
class RateLimiterService {
  // Store request timestamps per endpoint
  final Map<String, Queue<DateTime>> _requestHistory = {};
  
  // Rate limit configurations per endpoint type
  static final Map<String, RateLimitConfig> _configs = {
    // Authentication endpoints - stricter limits to prevent brute force
    'auth_login': RateLimitConfig(maxRequests: 5, windowMinutes: 1),
    'auth_register': RateLimitConfig(maxRequests: 3, windowMinutes: 5),
    'auth_otp': RateLimitConfig(maxRequests: 3, windowMinutes: 1),
    'auth_password_reset': RateLimitConfig(maxRequests: 3, windowMinutes: 5),
    
    // Part requests - moderate limits
    'create_request': RateLimitConfig(maxRequests: 10, windowMinutes: 1),
    'get_requests': RateLimitConfig(maxRequests: 30, windowMinutes: 1),
    
    // Chat/messaging - higher limits for real-time feel
    'send_message': RateLimitConfig(maxRequests: 30, windowMinutes: 1),
    'get_messages': RateLimitConfig(maxRequests: 60, windowMinutes: 1),
    
    // Offers - moderate limits
    'create_offer': RateLimitConfig(maxRequests: 20, windowMinutes: 1),
    'accept_offer': RateLimitConfig(maxRequests: 10, windowMinutes: 1),
    
    // Search/browse - generous limits
    'search': RateLimitConfig(maxRequests: 30, windowMinutes: 1),
    'get_shops': RateLimitConfig(maxRequests: 30, windowMinutes: 1),
    
    // Image upload - stricter due to bandwidth
    'upload_image': RateLimitConfig(maxRequests: 10, windowMinutes: 1),
    
    // Default for unspecified endpoints
    'default': RateLimitConfig(
      maxRequests: EnvironmentConfig.maxRequestsPerMinute, 
      windowMinutes: 1,
    ),
  };
  
  /// Check if a request should be allowed
  bool shouldAllowRequest(String endpoint) {
    if (!EnvironmentConfig.enableRateLimiting) {
      return true; // Rate limiting disabled
    }
    
    final config = _configs[endpoint] ?? _configs['default']!;
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(minutes: config.windowMinutes));
    
    // Initialize history for this endpoint if needed
    _requestHistory[endpoint] ??= Queue<DateTime>();
    final history = _requestHistory[endpoint]!;
    
    // Remove expired entries
    while (history.isNotEmpty && history.first.isBefore(windowStart)) {
      history.removeFirst();
    }
    
    // Check if under limit
    return history.length < config.maxRequests;
  }
  
  /// Record a request (call after shouldAllowRequest returns true)
  void recordRequest(String endpoint) {
    if (!EnvironmentConfig.enableRateLimiting) {
      return;
    }
    
    _requestHistory[endpoint] ??= Queue<DateTime>();
    _requestHistory[endpoint]!.add(DateTime.now());
  }
  
  /// Get remaining requests for an endpoint
  int getRemainingRequests(String endpoint) {
    if (!EnvironmentConfig.enableRateLimiting) {
      return 999; // Unlimited when disabled
    }
    
    final config = _configs[endpoint] ?? _configs['default']!;
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(minutes: config.windowMinutes));
    
    final history = _requestHistory[endpoint];
    if (history == null) {
      return config.maxRequests;
    }
    
    // Count valid (non-expired) requests
    final validRequests = history.where((t) => t.isAfter(windowStart)).length;
    return config.maxRequests - validRequests;
  }
  
  /// Get time until rate limit resets
  Duration? getTimeUntilReset(String endpoint) {
    final config = _configs[endpoint] ?? _configs['default']!;
    final history = _requestHistory[endpoint];
    
    if (history == null || history.isEmpty) {
      return null;
    }
    
    final oldestRequest = history.first;
    final resetTime = oldestRequest.add(Duration(minutes: config.windowMinutes));
    final now = DateTime.now();
    
    if (resetTime.isAfter(now)) {
      return resetTime.difference(now);
    }
    
    return null;
  }
  
  /// Execute a request with rate limiting
  /// Throws RateLimitExceededException if limit exceeded
  Future<T> executeWithRateLimit<T>(
    String endpoint,
    Future<T> Function() request,
  ) async {
    if (!shouldAllowRequest(endpoint)) {
      final retryAfter = getTimeUntilReset(endpoint) ?? const Duration(seconds: 60);
      throw RateLimitExceededException(
        'Too many requests. Please wait before trying again.',
        retryAfter,
      );
    }
    
    recordRequest(endpoint);
    return await request();
  }
  
  /// Clear rate limit history (useful for testing)
  void clearHistory([String? endpoint]) {
    if (endpoint != null) {
      _requestHistory.remove(endpoint);
    } else {
      _requestHistory.clear();
    }
  }
  
  /// Get current rate limit status for debugging
  Map<String, Map<String, dynamic>> getStatus() {
    final status = <String, Map<String, dynamic>>{};
    
    for (final endpoint in _requestHistory.keys) {
      status[endpoint] = {
        'remaining': getRemainingRequests(endpoint),
        'resetIn': getTimeUntilReset(endpoint)?.inSeconds,
      };
    }
    
    return status;
  }
}

/// Rate limit configuration for an endpoint
class RateLimitConfig {
  final int maxRequests;
  final int windowMinutes;
  
  const RateLimitConfig({
    required this.maxRequests,
    required this.windowMinutes,
  });
}
