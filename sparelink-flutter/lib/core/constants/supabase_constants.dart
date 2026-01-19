/// Supabase Configuration for SpareLink Backend
/// 
/// Configuration is loaded from environment variables at build time.
/// For local development, use: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// For production (Vercel), set these in the Vercel dashboard environment variables.
class SupabaseConstants {
  // ===========================================
  // Environment Variables (set at build time)
  // ===========================================
  
  /// Your Supabase project URL (from environment or fallback for development)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zcxsbfzezfjnkxwnnklf.supabase.co',
  );
  
  /// Your Supabase anon/public key (from environment or fallback for development)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjeHNiZnplemZqbmt4d25ua2xmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgxNDY1MjIsImV4cCI6MjA4MzcyMjUyMn0.lHSBwHRery2A5wMy0A2Zhlk-HzTvWXhGR0GIjybrlec',
  );
  
  // ===========================================
  // Storage Buckets
  // ===========================================
  
  /// Bucket for part images uploaded by mechanics
  static const String partImagesBucket = 'part-images';
  
  // ===========================================
  // Table Names
  // ===========================================
  
  static const String profilesTable = 'profiles';
  static const String shopsTable = 'shops';
  static const String partRequestsTable = 'part_requests';
  static const String offersTable = 'offers';
  static const String ordersTable = 'orders';
  static const String conversationsTable = 'conversations';
  static const String messagesTable = 'messages';
  
  // ===========================================
  // Function Names (for RPC calls)
  // ===========================================
  
  /// Get shops within radius of a location
  static const String nearbyShopsFunction = 'nearby_shops';
}
