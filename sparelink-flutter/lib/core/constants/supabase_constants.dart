/// Supabase Configuration for SpareLink Backend
/// 
/// IMPORTANT: Replace these with your actual Supabase project credentials
/// You can find these in: Supabase Dashboard → Settings → API
class SupabaseConstants {
  // ===========================================
  // TODO: REPLACE THESE WITH YOUR CREDENTIALS
  // ===========================================
  
  /// Your Supabase project URL
  static const String supabaseUrl = 'https://zcxsbfzezfjnkxwnnklf.supabase.co';
  
  /// Your Supabase anon/public key
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjeHNiZnplemZqbmt4d25ua2xmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgxNDY1MjIsImV4cCI6MjA4MzcyMjUyMn0.lHSBwHRery2A5wMy0A2Zhlk-HzTvWXhGR0GIjybrlec';
  
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
