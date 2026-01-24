import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/sparelink_logo.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/resilient_realtime_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/environment_config.dart';

/// Home screen stats data model
class HomeStats {
  final int pendingQuotes;
  final int activeDeliveries;
  final int totalRequests;
  final int unreadMessages;
  
  HomeStats({
    this.pendingQuotes = 0,
    this.activeDeliveries = 0,
    this.totalRequests = 0,
    this.unreadMessages = 0,
  });
}

/// Recent activity item model
class RecentActivity {
  final String id;
  final String type; // 'quote', 'delivery', 'request', 'message'
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? status;
  
  RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.status,
  });
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isCheckingRole = true;
  bool _isLoadingData = true;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  // Data
  HomeStats _stats = HomeStats();
  List<RecentActivity> _recentActivity = [];
  int _unreadNotifications = 0;
  String _userName = '';
  
  // Real-time subscriptions for instant updates
  ResilientRealtimeChannel? _offersChannel;
  ResilientRealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }
  
  @override
  void dispose() {
    _offersChannel?.dispose();
    _messagesChannel?.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    try {
      final storageService = ref.read(storageServiceProvider);
      final supabaseService = ref.read(supabaseServiceProvider);
      
      String? role = await storageService.getUserRole();
      String? name = await storageService.getUserName();
      
      if (role == null || role.isEmpty) {
        final user = supabaseService.currentUser;
        if (user != null) {
          final profile = await supabaseService.getProfile(user.id);
          role = profile?['role'] as String?;
          name = profile?['full_name'] as String?;
          
          if (role != null) {
            await storageService.saveUserData(
              userId: user.id,
              role: role,
              name: name ?? '',
              phone: profile?['phone'] ?? '',
            );
          }
        }
      }
      
      if (role == 'shop') {
        final session = Supabase.instance.client.auth.currentSession;
        await _redirectToShopDashboard(session?.accessToken);
        return;
      }
      
      if (mounted) {
        setState(() {
          _isCheckingRole = false;
          _userName = name ?? '';
        });
        _loadHomeData();
        _setupRealtimeSubscriptions();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingRole = false);
        _loadHomeData();
      }
    }
  }

  Future<void> _loadHomeData() async {
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final user = supabaseService.currentUser;
      
      if (user == null) {
        setState(() => _isLoadingData = false);
        return;
      }

      // Load stats and activity in parallel
      final results = await Future.wait([
        _loadStats(user.id),
        _loadRecentActivity(user.id),
        _loadUnreadNotifications(user.id),
      ]);
      
      if (mounted) {
        setState(() {
          _stats = results[0] as HomeStats;
          _recentActivity = results[1] as List<RecentActivity>;
          _unreadNotifications = results[2] as int;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  Future<HomeStats> _loadStats(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      
      int totalRequests = 0;
      int pendingQuotes = 0;
      
      // Try the optimized view first, fallback to direct table query
      try {
        // BUG FIX: Use part_requests_with_counts view for accurate counts
        final requestsWithCounts = await supabase
            .from('part_requests_with_counts')
            .select('id, status, offer_count, quoted_count')
            .eq('mechanic_id', userId);
        
        final requestsList = requestsWithCounts as List;
        totalRequests = requestsList.length;
        
        // Count pending quotes from the view's offer_count
        for (final req in requestsList) {
          if (req['status'] == 'pending' || req['status'] == 'offered') {
            pendingQuotes += (req['offer_count'] as int? ?? 0);
          }
        }
        debugPrint('📊 [HomeStats] Using view - found $totalRequests requests');
      } catch (viewError) {
        debugPrint('⚠️ [HomeStats] View failed, using fallback: $viewError');
        
        // FALLBACK: Direct table query if view doesn't exist or RLS blocks it
        final directRequests = await supabase
            .from('part_requests')
            .select('id, status')
            .eq('mechanic_id', userId);
        
        final requestsList = directRequests as List;
        totalRequests = requestsList.length;
        debugPrint('📊 [HomeStats] Using direct query - found $totalRequests requests');
        
        // Get pending offers count separately
        if (totalRequests > 0) {
          try {
            final requestIds = requestsList.map((r) => r['id'] as String).toList();
            final offersResponse = await supabase
                .from('offers')
                .select('id')
                .inFilter('request_id', requestIds)
                .eq('status', 'pending');
            pendingQuotes = (offersResponse as List).length;
          } catch (_) {}
        }
      }
      
      // Get active deliveries (orders in transit)
      int activeDeliveries = 0;
      try {
        final deliveriesResponse = await supabase
            .from('orders')
            .select('id')
            .eq('mechanic_id', userId)
            .inFilter('status', ['confirmed', 'preparing', 'processing', 'shipped', 'out_for_delivery']);
        activeDeliveries = (deliveriesResponse as List).length;
      } catch (e) {
        debugPrint('⚠️ [HomeStats] Orders query failed: $e');
      }
      
      // BUG FIX: Get unread messages using proper RLS-enabled query
      int unreadMessages = 0;
      
      try {
        // Regular conversation messages
        final regularMessages = await supabase
            .from('messages')
            .select('id')
            .eq('read', false)
            .neq('sender_id', userId);
        unreadMessages += (regularMessages as List).length;
      } catch (_) {}
      
      try {
        // Request chat messages (unread from shops) - try both column names
        try {
          final requestChatMessages = await supabase
              .from('request_chat_messages')
              .select('id')
              .eq('is_read', false)
              .neq('sender_id', userId);
          unreadMessages += (requestChatMessages as List).length;
        } catch (_) {
          // Fallback: try 'read' instead of 'is_read'
          final requestChatMessages = await supabase
              .from('request_chat_messages')
              .select('id')
              .eq('read', false)
              .neq('sender_id', userId);
          unreadMessages += (requestChatMessages as List).length;
        }
      } catch (_) {}
      
      debugPrint('📊 [HomeStats] Final: Requests=$totalRequests, Quotes=$pendingQuotes, Deliveries=$activeDeliveries, Unread=$unreadMessages');
      
      return HomeStats(
        pendingQuotes: pendingQuotes,
        activeDeliveries: activeDeliveries,
        totalRequests: totalRequests,
        unreadMessages: unreadMessages,
      );
    } catch (e) {
      debugPrint('❌ [HomeStats] Error loading stats: $e');
      return HomeStats();
    }
  }

  Future<List<RecentActivity>> _loadRecentActivity(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final activities = <RecentActivity>[];
      
      // Try view first, fallback to direct table
      List<dynamic> requests = [];
      try {
        requests = await supabase
            .from('part_requests_with_counts')
            .select('id, part_name, status, created_at, offer_count')
            .eq('mechanic_id', userId)
            .order('created_at', ascending: false)
            .limit(3);
      } catch (e) {
        debugPrint('⚠️ [RecentActivity] View failed, using fallback: $e');
        requests = await supabase
            .from('part_requests')
            .select('id, part_name, status, created_at')
            .eq('mechanic_id', userId)
            .order('created_at', ascending: false)
            .limit(3);
      }
      
      for (final req in requests) {
        final offerCount = req['offer_count'] as int? ?? 0;
        activities.add(RecentActivity(
          id: req['id'],
          type: 'request',
          title: req['part_name'] ?? 'Part Request',
          subtitle: offerCount > 0 
              ? '$offerCount quote${offerCount > 1 ? 's' : ''} received'
              : 'Status: ${req['status'] ?? 'pending'}',
          timestamp: DateTime.parse(req['created_at']),
          status: req['status'],
        ));
      }
      
      // Try to get recent offers (may fail due to RLS or schema differences)
      try {
        final offers = await supabase
            .from('offers')
            .select('id, price_cents, status, created_at, shops(name), part_requests!inner(mechanic_id, part_name)')
            .eq('part_requests.mechanic_id', userId)
            .order('created_at', ascending: false)
            .limit(3);
        
        for (final offer in (offers as List)) {
          final priceCents = offer['price_cents'] as int? ?? 0;
          final priceRands = (priceCents / 100).toStringAsFixed(0);
          final shopName = offer['shops']?['name'] ?? 'Shop';
          activities.add(RecentActivity(
            id: offer['id'],
            type: 'quote',
            title: 'Quote: R$priceRands from $shopName',
            subtitle: offer['part_requests']?['part_name'] ?? 'Part',
            timestamp: DateTime.parse(offer['created_at']),
            status: offer['status'],
          ));
        }
      } catch (e) {
        debugPrint('⚠️ [RecentActivity] Offers query failed: $e');
        // Try simpler offers query without joins
        try {
          final simpleOffers = await supabase
              .from('offers')
              .select('id, price_cents, status, created_at, request_id')
              .order('created_at', ascending: false)
              .limit(3);
          
          for (final offer in (simpleOffers as List)) {
            final priceCents = offer['price_cents'] as int? ?? 0;
            final priceRands = (priceCents / 100).toStringAsFixed(0);
            activities.add(RecentActivity(
              id: offer['id'],
              type: 'quote',
              title: 'Quote: R$priceRands',
              subtitle: 'New quote received',
              timestamp: DateTime.parse(offer['created_at']),
              status: offer['status'],
            ));
          }
        } catch (_) {}
      }
      
      // Sort by timestamp
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return activities.take(5).toList();
    } catch (e) {
      debugPrint('❌ [RecentActivity] Error loading: $e');
      return [];
    }
  }

  Future<int> _loadUnreadNotifications(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Set up real-time subscriptions for instant dashboard updates
  void _setupRealtimeSubscriptions() {
    final supabaseService = ref.read(supabaseServiceProvider);
    final user = supabaseService.currentUser;
    if (user == null) return;
    
    final client = Supabase.instance.client;
    
    // Subscribe to new offers on mechanic's requests
    _offersChannel = ResilientRealtimeChannel(
      client: client,
      channelName: 'home_offers_${user.id}',
      table: 'offers',
      event: PostgresChangeEvent.insert,
    );
    
    _offersChannel!.subscribe(
      onData: (data) {
        debugPrint('🔔 [Home] New offer received - refreshing stats');
        // Refresh stats when new offer arrives
        _loadHomeData();
        
        // Show snackbar notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('New quote received!')),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => context.push('/my-requests'),
              ),
            ),
          );
        }
      },
      onStateChange: (state) {
        debugPrint('🔔 [Home] Offers channel state: $state');
      },
      onError: (error) {
        debugPrint('❌ [Home] Offers channel error: $error');
      },
    );
    
    // Subscribe to new messages
    _messagesChannel = ResilientRealtimeChannel(
      client: client,
      channelName: 'home_messages_${user.id}',
      table: 'request_chat_messages',
      event: PostgresChangeEvent.insert,
    );
    
    _messagesChannel!.subscribe(
      onData: (data) {
        // Only notify if message is not from current user
        final senderId = data['sender_id'] as String?;
        if (senderId != user.id) {
          debugPrint('🔔 [Home] New message received - refreshing stats');
          _loadHomeData();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    Icon(LucideIcons.messageCircle, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text('New message from shop!')),
                  ],
                ),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Open',
                  textColor: Colors.white,
                  onPressed: () => context.push('/chats'),
                ),
              ),
            );
          }
        }
      },
      onStateChange: (state) {
        debugPrint('🔔 [Home] Messages channel state: $state');
      },
      onError: (error) {
        debugPrint('❌ [Home] Messages channel error: $error');
      },
    );
  }

  Future<void> _onRefresh() async {
    await _loadHomeData();
  }

  void _onSearch(String query) {
    if (query.trim().isNotEmpty) {
      context.push('/request-part', extra: {'searchQuery': query.trim()});
    }
  }

  Future<void> _redirectToShopDashboard(String? accessToken) async {
    const shopDashboardUrl = EnvironmentConfig.shopDashboardUrl;
    
    if (kIsWeb) {
      final uri = Uri.parse('$shopDashboardUrl/dashboard?token=$accessToken');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        _showShopRedirectDialog();
      }
    } else {
      _showShopRedirectDialog();
    }
  }

  void _showShopRedirectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        title: const Text('Shop Account Detected', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This app is for mechanics to request parts.', style: TextStyle(color: AppTheme.lightGray)),
            SizedBox(height: 16),
            Text('As a shop owner, please use the Shop Dashboard:', style: TextStyle(color: AppTheme.lightGray)),
            SizedBox(height: 12),
            Text(EnvironmentConfig.shopDashboardUrl, style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
              final storageService = ref.read(storageServiceProvider);
              await storageService.clearAll();
              if (mounted) context.go('/login');
            },
            child: const Text('Sign Out'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              const url = EnvironmentConfig.shopDashboardUrl;
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: const Text('Open Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingRole) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpareLinkLogo(size: 64, color: Colors.white),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
            ],
          ),
        ),
      );
    }
    
    return _buildHomeContent(context);
  }

  Widget _buildHomeContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFF2C2C2C), Color(0xFF000000)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppTheme.accentGreen,
                    backgroundColor: AppTheme.darkGray,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 40 : 20,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _buildSearchBar(),
                              const SizedBox(height: 24),
                              if (isDesktop)
                                _buildDesktopStats()
                              else
                                _buildQuickStats(),
                              const SizedBox(height: 24),
                              if (isDesktop)
                                _buildDesktopGridCards()
                              else
                                _buildGridCards(),
                              const SizedBox(height: 24),
                              _buildRecentActivity(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Bottom nav is now handled by ResponsiveShell on mobile
      // On desktop, sidebar is shown instead
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const SpareLinkLogo(size: 32, color: Colors.white),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SpareLink', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  Text(
                    _userName.isNotEmpty ? 'Hi, ${_userName.split(' ').first}' : 'Mechanics',
                    style: const TextStyle(color: Colors.grey, fontSize: 14, height: 0.8),
                  ),
                ],
              ),
            ],
          ),
          // Notification Bell with Badge
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.bell, color: Colors.white, size: 22),
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search for parts...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: const Icon(LucideIcons.search, color: Colors.grey, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(LucideIcons.arrowRight, color: AppTheme.accentGreen, size: 20),
            onPressed: () => _onSearch(_searchController.text),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        onSubmitted: _onSearch,
      ),
    );
  }

  Widget _buildQuickStats() {
    if (_isLoadingData) {
      return Row(
        children: const [
          Expanded(child: SkeletonStatCard()),
          SizedBox(width: 12),
          Expanded(child: SkeletonStatCard()),
          SizedBox(width: 12),
          Expanded(child: SkeletonStatCard()),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(child: _buildStatCard('${_stats.pendingQuotes}', 'Pending\nQuotes', LucideIcons.fileText, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('${_stats.activeDeliveries}', 'Active\nDeliveries', LucideIcons.truck, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('${_stats.unreadMessages}', 'Unread\nMessages', LucideIcons.messageCircle, AppTheme.accentGreen)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (label.contains('Quotes')) context.push('/my-requests');
        else if (label.contains('Deliveries')) context.push('/my-requests');
        else if (label.contains('Messages')) context.push('/chats');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCards() {
    if (_isLoadingData) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.95,
        children: const [SkeletonGridCard(), SkeletonGridCard(), SkeletonGridCard(), SkeletonGridCard()],
      );
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.95,
      children: [
        _buildClickableGridCard(
          iconWidget: const SpareLinkLogo(size: 40, color: Colors.white),
          title: 'Request a Part',
          subtitle: 'Find parts from nearby shops',
          onTap: () => context.push('/request-part'),
        ),
        _buildClickableGridCard(
          icon: LucideIcons.clipboardList,
          title: 'My Requests',
          subtitle: 'Track offers and orders',
          badge: _stats.pendingQuotes > 0 ? '${_stats.pendingQuotes}' : null,
          onTap: () => context.push('/my-requests'),
        ),
        _buildClickableGridCard(
          icon: LucideIcons.truck,
          title: 'Deliveries',
          subtitle: 'Track incoming parts',
          badge: _stats.activeDeliveries > 0 ? '${_stats.activeDeliveries}' : null,
          onTap: () => context.push('/my-requests'),
        ),
        _buildClickableGridCard(
          icon: LucideIcons.messageCircle,
          title: 'Chats',
          subtitle: 'Discuss with suppliers',
          badge: _stats.unreadMessages > 0 ? '${_stats.unreadMessages}' : null,
          onTap: () => context.push('/chats'),
        ),
      ],
    );
  }

  Widget _buildClickableGridCard({
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  iconWidget ?? Icon(icon, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    title, 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(badge, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Activity', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => context.push('/my-requests'),
              child: const Text('View All', style: TextStyle(color: AppTheme.accentGreen, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingData)
          Column(children: const [SkeletonActivityItem(), SkeletonActivityItem(), SkeletonActivityItem()])
        else if (_recentActivity.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.inbox, color: Colors.grey[600], size: 48),
                const SizedBox(height: 12),
                const Text('No recent activity', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Request a part to get started!', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )
        else
          ...(_recentActivity.map((activity) => _buildActivityItem(activity))),
      ],
    );
  }

  Widget _buildActivityItem(RecentActivity activity) {
    IconData icon;
    Color color;
    
    switch (activity.type) {
      case 'quote':
        icon = LucideIcons.fileText;
        color = Colors.orange;
        break;
      case 'delivery':
        icon = LucideIcons.truck;
        color = Colors.blue;
        break;
      case 'message':
        icon = LucideIcons.messageCircle;
        color = AppTheme.accentGreen;
        break;
      default:
        icon = LucideIcons.clipboardList;
        color = Colors.purple;
    }
    
    final timeAgo = _getTimeAgo(activity.timestamp);
    
    return GestureDetector(
      onTap: () => context.push('/my-requests'),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(activity.subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                if (activity.status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(activity.status!).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      activity.status!,
                      style: TextStyle(color: _getStatusColor(activity.status!), fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'accepted': return AppTheme.accentGreen;
      case 'rejected': return Colors.red;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  /// Desktop-optimized stats row with 4 columns
  Widget _buildDesktopStats() {
    if (_isLoadingData) {
      return Row(
        children: const [
          Expanded(child: SkeletonStatCard()),
          SizedBox(width: 16),
          Expanded(child: SkeletonStatCard()),
          SizedBox(width: 16),
          Expanded(child: SkeletonStatCard()),
          SizedBox(width: 16),
          Expanded(child: SkeletonStatCard()),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(child: _buildDesktopStatCard('${_stats.pendingQuotes}', 'Pending Quotes', LucideIcons.fileText, Colors.orange, '/my-requests')),
        const SizedBox(width: 16),
        Expanded(child: _buildDesktopStatCard('${_stats.activeDeliveries}', 'Active Deliveries', LucideIcons.truck, Colors.blue, '/my-requests')),
        const SizedBox(width: 16),
        Expanded(child: _buildDesktopStatCard('${_stats.totalRequests}', 'Total Requests', LucideIcons.clipboardList, Colors.purple, '/my-requests')),
        const SizedBox(width: 16),
        Expanded(child: _buildDesktopStatCard('${_stats.unreadMessages}', 'Unread Messages', LucideIcons.messageCircle, AppTheme.accentGreen, '/chats')),
      ],
    );
  }

  Widget _buildDesktopStatCard(String value, String label, IconData icon, Color color, String route) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: color.withOpacity(0.5), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Desktop-optimized grid with 4 columns
  Widget _buildDesktopGridCards() {
    if (_isLoadingData) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 1.1,
        children: const [SkeletonGridCard(), SkeletonGridCard(), SkeletonGridCard(), SkeletonGridCard()],
      );
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: 1.1,
      children: [
        _buildDesktopGridCard(
          iconWidget: const SpareLinkLogo(size: 48, color: Colors.white),
          title: 'Request a Part',
          subtitle: 'Find parts from nearby shops',
          onTap: () => context.push('/request-part'),
          isPrimary: true,
        ),
        _buildDesktopGridCard(
          icon: LucideIcons.clipboardList,
          title: 'My Requests',
          subtitle: 'Track your part requests and offers',
          badge: _stats.pendingQuotes > 0 ? '${_stats.pendingQuotes}' : null,
          onTap: () => context.push('/my-requests'),
        ),
        _buildDesktopGridCard(
          icon: LucideIcons.truck,
          title: 'Deliveries',
          subtitle: 'Track incoming parts',
          badge: _stats.activeDeliveries > 0 ? '${_stats.activeDeliveries}' : null,
          onTap: () => context.push('/my-requests'),
        ),
        _buildDesktopGridCard(
          icon: LucideIcons.messageCircle,
          title: 'Chats',
          subtitle: 'Discuss with suppliers',
          badge: _stats.unreadMessages > 0 ? '${_stats.unreadMessages}' : null,
          onTap: () => context.push('/chats'),
        ),
      ],
    );
  }

  Widget _buildDesktopGridCard({
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isPrimary 
                ? AppTheme.accentGreen.withOpacity(0.15)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPrimary
                  ? AppTheme.accentGreen.withOpacity(0.4)
                  : Colors.white.withOpacity(0.1),
              width: isPrimary ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconWidget ?? Icon(
                      icon, 
                      color: isPrimary ? AppTheme.accentGreen : Colors.white, 
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title, 
                      textAlign: TextAlign.center, 
                      style: TextStyle(
                        color: isPrimary ? AppTheme.accentGreen : Colors.white, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle, 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge, 
                      style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
