import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/models/marketplace.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/sparelink_logo.dart';

/// My Requests Screen
/// Clean dark-mode list view of requests with thumbnails, titles, shop details, and status badges
class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  List<PartRequest> _requests = [];
  bool _isLoading = true;
  String? _error;

  // Design constants matching reference
  static const Color _backgroundColor = Color(0xFF121212);
  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _badgeBackground = Color(0xFF333333);
  static const Color _subtitleGray = Color(0xFFB0B0B0);

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final currentUser = supabaseService.currentUser;
      
      if (currentUser == null) {
        setState(() {
          _error = 'Please log in to view your requests';
          _isLoading = false;
        });
        return;
      }
      
      // Fetch requests from Supabase
      final requestsData = await supabaseService.getMechanicRequests(currentUser.id);
      
      // Convert to PartRequest objects
      _requests = requestsData.map((data) => PartRequest.fromJson(data)).toList();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load requests: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'My Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : _requests.isEmpty
                          ? _buildEmptyState()
                          : _buildRequestsList(),
            ),
          ],
        ),
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button and logo
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    LucideIcons.arrowLeft,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SpareLinkFullLogo(iconSize: 28),
            ],
          ),
          // Notification icon
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: const Icon(
              LucideIcons.bell,
              color: _subtitleGray,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.circleAlert,
              size: 60,
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadRequests,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.clipboardList,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 24),
            const Text(
              'No requests yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the button below to request your first part!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.push('/camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Request a Part',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: Colors.white,
      backgroundColor: _cardBackground,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          return _RequestCard(
            request: _requests[index],
            onTap: () {
              // Navigate based on status
              if (_requests[index].status == RequestStatus.offered ||
                  _requests[index].status == RequestStatus.pending) {
                context.push('/marketplace/${_requests[index].id}');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Request: ${_requests[index].displayId}')),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _cardBackground,
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: LucideIcons.grid3x3,
              label: 'Home',
              isActive: false,
              onTap: () => context.go('/'),
            ),
            _buildNavItem(
              icon: LucideIcons.clipboardList,
              label: 'My Requests',
              isActive: true,
              onTap: () {},
            ),
            _buildNavItem(
              icon: LucideIcons.messageCircle,
              label: 'Chats',
              isActive: false,
              onTap: () => context.push('/chats'),
            ),
            _buildNavItem(
              icon: LucideIcons.user,
              label: 'Profile',
              isActive: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.white : _subtitleGray,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : _subtitleGray,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Request Card Widget - matches reference design exactly
class _RequestCard extends StatelessWidget {
  final PartRequest request;
  final VoidCallback onTap;

  // Design constants
  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _badgeBackground = Color(0xFF333333);
  static const Color _subtitleGray = Color(0xFFB0B0B0);

  const _RequestCard({
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: const Color(0xFF2A2A2A),
                child: request.imageUrls != null && request.imageUrls!.isNotEmpty
                    ? Image.network(
                        request.imageUrls!.first,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage();
                        },
                      )
                    : _buildPlaceholderImage(),
              ),
            ),
            const SizedBox(width: 16),
            
            // Middle content: title and shop details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    request.partName ?? 'Part Request',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Shop details (matching reference format)
                  Text(
                    'Shop: ${request.partName ?? "Unknown"}',
                    style: const TextStyle(
                      color: _subtitleGray,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Vehicle: ${request.vehicleDisplay}',
                    style: const TextStyle(
                      color: _subtitleGray,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Submitted: ${request.timeAgo}',
                    style: const TextStyle(
                      color: _subtitleGray,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status badge - highlighted when offers received
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: request.status == RequestStatus.offered 
                    ? const Color(0xFF00C853) // Green when offers received
                    : request.status == RequestStatus.accepted
                        ? const Color(0xFF2196F3) // Blue when accepted
                        : _badgeBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (request.status == RequestStatus.offered) ...[
                    const Icon(LucideIcons.tag, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    request.statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      color: const Color(0xFF2A2A2A),
      child: const Icon(
        LucideIcons.image,
        color: _subtitleGray,
        size: 24,
      ),
    );
  }
}
