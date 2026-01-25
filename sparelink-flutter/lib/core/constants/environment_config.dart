/// Environment Configuration for SpareLink
/// 
/// This file centralizes all environment-specific URLs and settings.
/// For production deployment, these values should be configured via:
/// - Flutter: --dart-define flags during build
/// - Environment variables in CI/CD pipeline
/// 
/// Usage:
///   flutter run --dart-define=API_BASE_URL=https://api.sparelink.co.za
///   flutter run --dart-define=SHOP_DASHBOARD_URL=https://dashboard.sparelink.co.za
///   flutter run --dart-define=ENVIRONMENT=production

class EnvironmentConfig {
  // ===========================================
  // ENVIRONMENT DETECTION
  // ===========================================
  
  /// Current environment (development, staging, production)
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  
  /// Check if running in production
  static bool get isProduction => environment == 'production';
  
  /// Check if running in staging
  static bool get isStaging => environment == 'staging';
  
  /// Check if running in development
  static bool get isDevelopment => environment == 'development';
  
  // ===========================================
  // API CONFIGURATION
  // ===========================================
  
  /// Backend API Base URL
  /// 
  /// Development: http://localhost:3333/api
  /// Production: https://api.sparelink.co.za/api (configure via --dart-define)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3333/api',
  );
  
  // ===========================================
  // SHOP DASHBOARD CONFIGURATION
  // ===========================================
  
  /// Shop Dashboard URL for shop owner redirects
  /// 
  /// Development: http://localhost:3000
  /// Production: https://dashboard.sparelink.co.za (configure via --dart-define)
  static const String shopDashboardUrl = String.fromEnvironment(
    'SHOP_DASHBOARD_URL',
    defaultValue: 'http://localhost:3000',
  );
  
  // ===========================================
  // SUPABASE CONFIGURATION
  // ===========================================
  
  /// Supabase Project URL
  /// Can be overridden via environment for different environments
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zcxsbfzezfjnkxwnnklf.supabase.co',
  );
  
  /// Supabase Anonymous Key
  /// Can be overridden via environment for different environments
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjeHNiZnplemZqbmt4d25ua2xmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgxNDY1MjIsImV4cCI6MjA4MzcyMjUyMn0.lHSBwHRery2A5wMy0A2Zhlk-HzTvWXhGR0GIjybrlec',
  );
  
  // ===========================================
  // FEATURE FLAGS
  // ===========================================
  
  /// Enable rate limiting (should be true in production)
  static const bool enableRateLimiting = String.fromEnvironment(
    'ENABLE_RATE_LIMITING',
    defaultValue: 'true',
  ) == 'true';
  
  /// Enable audit logging (should be true in production)
  static const bool enableAuditLogging = String.fromEnvironment(
    'ENABLE_AUDIT_LOGGING',
    defaultValue: 'true',
  ) == 'true';
  
  /// Enable request validation (should be true always)
  static const bool enableRequestValidation = String.fromEnvironment(
    'ENABLE_REQUEST_VALIDATION',
    defaultValue: 'true',
  ) == 'true';
  
  // ===========================================
  // TIMEOUTS & LIMITS
  // ===========================================
  
  /// API connection timeout in seconds
  static const int connectTimeoutSeconds = int.fromEnvironment(
    'CONNECT_TIMEOUT_SECONDS',
    defaultValue: 10,
  );
  
  /// API receive timeout in seconds
  static const int receiveTimeoutSeconds = int.fromEnvironment(
    'RECEIVE_TIMEOUT_SECONDS',
    defaultValue: 15,
  );
  
  /// Maximum requests per minute (rate limiting)
  static const int maxRequestsPerMinute = int.fromEnvironment(
    'MAX_REQUESTS_PER_MINUTE',
    defaultValue: 60,
  );
  
  // ===========================================
  // HELPER METHODS
  // ===========================================
  
  /// Get configuration summary for debugging
  static Map<String, dynamic> get configSummary => {
    'environment': environment,
    'apiBaseUrl': apiBaseUrl,
    'shopDashboardUrl': shopDashboardUrl,
    'supabaseUrl': supabaseUrl,
    'enableRateLimiting': enableRateLimiting,
    'enableAuditLogging': enableAuditLogging,
    'enableRequestValidation': enableRequestValidation,
    'maxRequestsPerMinute': maxRequestsPerMinute,
  };
  
  /// Print configuration (for debugging, only in non-production)
  static void printConfig() {
    if (!isProduction) {
      print('=== SpareLink Environment Configuration ===');
      configSummary.forEach((key, value) {
        print('  $key: $value');
      });
      print('==========================================');
    }
  }
}
