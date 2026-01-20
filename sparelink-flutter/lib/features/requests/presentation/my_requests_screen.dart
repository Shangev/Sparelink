import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/models/marketplace.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/sparelink_logo.dart';
import '../../../shared/widgets/responsive_page_layout.dart';

/// My Requests Screen
/// Clean dark-mode list view of requests with thumbnails, titles, shop details, and status badges
class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  List<PartRequest> _requests = [];
  List<PartRequest> _filteredRequests = [];
  bool _isLoading = true;
  String? _error;
  
  // Search & Filter state
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, pending, offered, accepted, fulfilled, cancelled, expired
  String _dateFilter = 'all'; // all, today, week, month
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  
  // Bulk selection state
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};

  // Design constants matching reference
  static const Color _backgroundColor = Color(0xFF121212);
  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _badgeBackground = Color(0xFF333333);
  static const Color _subtitleGray = Color(0xFFB0B0B0);
  static const Color _accentGreen = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }
  
  void _applyFilters() {
    _filteredRequests = _requests.where((request) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = 
            (request.partName?.toLowerCase().contains(_searchQuery) ?? false) ||
            (request.vehicleMake?.toLowerCase().contains(_searchQuery) ?? false) ||
            (request.vehicleModel?.toLowerCase().contains(_searchQuery) ?? false) ||
            request.id.toLowerCase().contains(_searchQuery);
        if (!matchesSearch) return false;
      }
      
      // Status filter
      if (_statusFilter != 'all') {
        if (request.status.name != _statusFilter) return false;
      }
      
      // Date filter
      if (_dateFilter != 'all') {
        final now = DateTime.now();
        final requestDate = request.createdAt;
        
        switch (_dateFilter) {
          case 'today':
            if (requestDate.day != now.day || requestDate.month != now.month || requestDate.year != now.year) {
              return false;
            }
            break;
          case 'week':
            final weekAgo = now.subtract(const Duration(days: 7));
            if (requestDate.isBefore(weekAgo)) return false;
            break;
          case 'month':
            final monthAgo = now.subtract(const Duration(days: 30));
            if (requestDate.isBefore(monthAgo)) return false;
            break;
          case 'custom':
            if (_customStartDate != null && requestDate.isBefore(_customStartDate!)) return false;
            if (_customEndDate != null && requestDate.isAfter(_customEndDate!.add(const Duration(days: 1)))) return false;
            break;
        }
      }
      
      return true;
    }).toList();
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
      _applyFilters();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load requests: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // Bulk actions
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }
  
  void _toggleSelection(String requestId) {
    setState(() {
      if (_selectedIds.contains(requestId)) {
        _selectedIds.remove(requestId);
      } else {
        _selectedIds.add(requestId);
      }
    });
  }
  
  void _selectAll() {
    setState(() {
      _selectedIds = _filteredRequests
          .where((r) => r.status == RequestStatus.pending || r.status == RequestStatus.offered)
          .map((r) => r.id)
          .toSet();
    });
  }
  
  Future<void> _cancelSelected() async {
    if (_selectedIds.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBackground,
        title: const Text('Cancel Requests?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to cancel ${_selectedIds.length} request(s)? This cannot be undone.',
          style: const TextStyle(color: _subtitleGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: _subtitleGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final supabaseService = ref.read(supabaseServiceProvider);
      for (final id in _selectedIds) {
        await supabaseService.updateRequestStatus(id, 'cancelled');
      }
      _toggleSelectionMode();
      _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedIds.length} request(s) cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  // Duplicate request
  Future<void> _duplicateRequest(PartRequest request) async {
    // Navigate to request part screen with pre-filled data
    context.push('/request-part', extra: {
      'duplicate': true,
      'vehicleMake': request.vehicleMake,
      'vehicleModel': request.vehicleModel,
      'vehicleYear': request.vehicleYear?.toString(),
      'partName': request.partName,
    });
  }
  
  // Show filter bottom sheet
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _buildFilterSheet(ctx),
    );
  }
  
  Widget _buildFilterSheet(BuildContext ctx) {
    return StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter Requests', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _statusFilter = 'all';
                      _dateFilter = 'all';
                      _customStartDate = null;
                      _customEndDate = null;
                      _applyFilters();
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Clear All', style: TextStyle(color: _accentGreen)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Status Filter
            const Text('Status', style: TextStyle(color: _subtitleGray, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('All', 'all', _statusFilter, (v) {
                  setSheetState(() {});
                  setState(() { _statusFilter = v; _applyFilters(); });
                }),
                _buildFilterChip('Pending', 'pending', _statusFilter, (v) {
                  setSheetState(() {});
                  setState(() { _statusFilter = v; _applyFilters(); });
                }),
                _buildFilterChip('Quoted', 'offered', _statusFilter, (v) {
                  setSheetState(() {});
                  setState(() { _statusFilter = v; _applyFilters(); });
                }),
                _buildFilterChip('Accepted', 'accepted', _statusFilter, (v) {
                  setSheetState(() {});
                  setState(() { _statusFilter = v; _applyFilters(); });
                }),
                _buildFilterChip('Completed', 'fulfilled', _statusFilter, (v) {
                  setSheetState(() {});
                  setState(() { _statusFilter = v; _applyFilters(); });
                }),
                _buildFilterChip('Cancelled', 'cancelled', _statusFilter, (v) {
                  setSheetState(() {});
                  setState(() { _statusFilter = v; _applyFilters(); });
                }),
              ],
            ),
            const SizedBox(height: 20),
            
            // Date Filter
            const Text('Date Range', style: TextStyle(color: _subtitleGray, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('All Time', 'all', _dateFilter, (v) {
                  setSheetState(() {});
                  setState(() { _dateFilter = v; _applyFilters(); });
                }),
                _buildFilterChip('Today', 'today', _dateFilter, (v) {
                  setSheetState(() {});
                  setState(() { _dateFilter = v; _applyFilters(); });
                }),
                _buildFilterChip('This Week', 'week', _dateFilter, (v) {
                  setSheetState(() {});
                  setState(() { _dateFilter = v; _applyFilters(); });
                }),
                _buildFilterChip('This Month', 'month', _dateFilter, (v) {
                  setSheetState(() {});
                  setState(() { _dateFilter = v; _applyFilters(); });
                }),
              ],
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Show ${_filteredRequests.length} Results'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value, String currentValue, Function(String) onTap) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accentGreen : _backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _accentGreen : Colors.grey[700]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
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
            
            // Title Row with Selection Mode Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSelectionMode ? '${_selectedIds.length} Selected' : 'My Requests',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isLoading && _requests.isNotEmpty)
                    Row(
                      children: [
                        if (_isSelectionMode) ...[
                          TextButton(
                            onPressed: _selectAll,
                            child: const Text('Select All', style: TextStyle(color: _accentGreen, fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        GestureDetector(
                          onTap: _toggleSelectionMode,
                          child: Icon(
                            _isSelectionMode ? LucideIcons.x : LucideIcons.squareCheck,
                            color: _isSelectionMode ? Colors.white : _subtitleGray,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            // Search Bar and Filter Button
            if (!_isLoading && _requests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search by part, vehicle...',
                            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                            prefixIcon: Icon(LucideIcons.search, color: Colors.grey[600], size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filter Button
                    GestureDetector(
                      onTap: _showFilterSheet,
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: (_statusFilter != 'all' || _dateFilter != 'all') ? _accentGreen : _cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          LucideIcons.slidersHorizontal,
                          color: (_statusFilter != 'all' || _dateFilter != 'all') ? Colors.black : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Active Filters Display
            if (_statusFilter != 'all' || _dateFilter != 'all')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text('${_filteredRequests.length} of ${_requests.length} requests', 
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _statusFilter = 'all';
                          _dateFilter = 'all';
                          _applyFilters();
                        });
                      },
                      child: const Text('Clear filters', style: TextStyle(color: _accentGreen, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            
            // Bulk Actions Bar
            if (_isSelectionMode && _selectedIds.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2, color: Colors.red[400], size: 18),
                    const SizedBox(width: 8),
                    Text('${_selectedIds.length} selected', style: TextStyle(color: Colors.red[400])),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _cancelSelected,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Cancel Selected', style: TextStyle(fontSize: 13)),
                    ),
                  ],
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
                          : _filteredRequests.isEmpty
                              ? _buildNoResultsState()
                              : _buildRequestsList(),
            ),
          ],
        ),
      ),
      // Bottom nav is provided by ResponsiveShell - removed duplicate
    );
  }
  
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.searchX, size: 60, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('No matching requests', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Try adjusting your search or filters', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _statusFilter = 'all';
                _dateFilter = 'all';
                _applyFilters();
              });
            },
            child: const Text('Clear all filters', style: TextStyle(color: _accentGreen)),
          ),
        ],
      ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    
    // Calculate grid columns based on screen width
    int crossAxisCount = 1;
    if (screenWidth >= 1400) {
      crossAxisCount = 4;
    } else if (screenWidth >= 1100) {
      crossAxisCount = 3;
    } else if (screenWidth >= 900) {
      crossAxisCount = 2;
    }
    
    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: Colors.white,
      backgroundColor: _cardBackground,
      child: isDesktop
          ? _buildGridView(crossAxisCount)
          : _buildListView(),
    );
  }
  
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredRequests.length,
      itemBuilder: (context, index) => _buildRequestCard(_filteredRequests[index]),
    );
  }
  
  Widget _buildGridView(int crossAxisCount) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4, // Wider cards for desktop
          ),
          itemCount: _filteredRequests.length,
          itemBuilder: (context, index) => _buildRequestGridCard(_filteredRequests[index]),
        ),
      ),
    );
  }
  
  Widget _buildRequestCard(PartRequest request) {
    final isSelected = _selectedIds.contains(request.id);
    final canSelect = request.status == RequestStatus.pending || request.status == RequestStatus.offered;
    
    return _RequestCard(
      request: request,
      isSelectionMode: _isSelectionMode,
      isSelected: isSelected,
      onTap: () => _handleRequestTap(request, canSelect),
      onLongPress: canSelect ? () {
        if (!_isSelectionMode) _toggleSelectionMode();
        _toggleSelection(request.id);
      } : null,
      onDuplicate: () => _duplicateRequest(request),
      onEdit: request.status == RequestStatus.pending ? () => _editRequest(request) : null,
    );
  }
  
  Widget _buildRequestGridCard(PartRequest request) {
    final isSelected = _selectedIds.contains(request.id);
    final canSelect = request.status == RequestStatus.pending || request.status == RequestStatus.offered;
    
    return _RequestGridCard(
      request: request,
      isSelectionMode: _isSelectionMode,
      isSelected: isSelected,
      onTap: () => _handleRequestTap(request, canSelect),
      onLongPress: canSelect ? () {
        if (!_isSelectionMode) _toggleSelectionMode();
        _toggleSelection(request.id);
      } : null,
      onDuplicate: () => _duplicateRequest(request),
      onEdit: request.status == RequestStatus.pending ? () => _editRequest(request) : null,
    );
  }
  
  void _handleRequestTap(PartRequest request, bool canSelect) {
    if (_isSelectionMode && canSelect) {
      _toggleSelection(request.id);
    } else {
      switch (request.status) {
        case RequestStatus.pending:
        case RequestStatus.offered:
          context.push('/marketplace/${request.id}');
          break;
        case RequestStatus.accepted:
        case RequestStatus.fulfilled:
        case RequestStatus.cancelled:
        case RequestStatus.expired:
          context.push('/request/${request.id}');
          break;
      }
    }
  }
  
  // Edit request - navigate to request part screen with existing data
  void _editRequest(PartRequest request) {
    context.push('/request-part', extra: {
      'edit': true,
      'requestId': request.id,
      'vehicleMake': request.vehicleMake,
      'vehicleModel': request.vehicleModel,
      'vehicleYear': request.vehicleYear?.toString(),
      'partName': request.partName,
      'description': request.description,
    });
  }

}

/// Request Card Widget - with selection mode and swipe actions
class _RequestCard extends StatelessWidget {
  final PartRequest request;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDuplicate;
  final VoidCallback? onEdit;
  final bool isSelectionMode;
  final bool isSelected;

  // Design constants
  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _badgeBackground = Color(0xFF333333);
  static const Color _subtitleGray = Color(0xFFB0B0B0);
  static const Color _accentGreen = Color(0xFF00E676);

  const _RequestCard({
    required this.request,
    required this.onTap,
    this.onLongPress,
    this.onDuplicate,
    this.onEdit,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(request.id),
      background: _buildSwipeBackground(LucideIcons.copy, 'Duplicate', Colors.blue, Alignment.centerLeft),
      secondaryBackground: onEdit != null 
          ? _buildSwipeBackground(LucideIcons.pencil, 'Edit', Colors.orange, Alignment.centerRight)
          : _buildSwipeBackground(LucideIcons.copy, 'Duplicate', Colors.blue, Alignment.centerRight),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onDuplicate?.call();
        } else if (direction == DismissDirection.endToStart) {
          if (onEdit != null) {
            onEdit!.call();
          } else {
            onDuplicate?.call();
          }
        }
        return false; // Don't actually dismiss
      },
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? _accentGreen.withOpacity(0.15) : _cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: _accentGreen, width: 2) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection checkbox (in selection mode)
              if (isSelectionMode) ...[
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 12, top: 18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? _accentGreen : Colors.transparent,
                    border: Border.all(color: isSelected ? _accentGreen : Colors.grey, width: 2),
                  ),
                  child: isSelected
                      ? const Icon(LucideIcons.check, color: Colors.black, size: 14)
                      : null,
                ),
              ],
              
              // Thumbnail image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60,
                  height: 60,
                  color: const Color(0xFF2A2A2A),
                  child: request.imageUrl != null && request.imageUrl!.isNotEmpty
                      ? Image.network(
                          request.imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white.withOpacity(0.5),
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderImage();
                          },
                        )
                      : _buildPlaceholderImage(),
                ),
              ),
              const SizedBox(width: 12),
              
              // Middle content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.partName ?? 'Part Request',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.vehicleDisplay,
                      style: const TextStyle(color: _subtitleGray, fontSize: 13),
                    ),
                    Text(
                      request.timeAgo,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Right side: Status badge and action menu
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (request.status == RequestStatus.offered) ...[
                          const Icon(LucideIcons.tag, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          request.statusLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Quick actions menu
                  if (!isSelectionMode)
                    PopupMenuButton<String>(
                      icon: Icon(LucideIcons.ellipsisVertical, color: Colors.grey[600], size: 18),
                      color: const Color(0xFF2A2A2A),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'duplicate', child: Row(
                          children: [
                            Icon(LucideIcons.copy, size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Duplicate', style: TextStyle(color: Colors.white)),
                          ],
                        )),
                        if (onEdit != null)
                          const PopupMenuItem(value: 'edit', child: Row(
                            children: [
                              Icon(LucideIcons.pencil, size: 16, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Edit', style: TextStyle(color: Colors.white)),
                            ],
                          )),
                      ],
                      onSelected: (value) {
                        if (value == 'duplicate') onDuplicate?.call();
                        if (value == 'edit') onEdit?.call();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSwipeBackground(IconData icon, String label, Color color, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerRight) ...[
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: Colors.white),
          if (alignment == Alignment.centerLeft) ...[
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
  
  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.offered:
        return const Color(0xFF00C853);
      case RequestStatus.accepted:
        return const Color(0xFF2196F3);
      case RequestStatus.fulfilled:
        return const Color(0xFF9C27B0);
      case RequestStatus.cancelled:
        return Colors.red;
      case RequestStatus.expired:
        return Colors.orange;
      case RequestStatus.pending:
      default:
        return _badgeBackground;
    }
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

/// Desktop Grid Card Widget - optimized for grid layout
class _RequestGridCard extends StatefulWidget {
  final PartRequest request;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDuplicate;
  final VoidCallback? onEdit;
  final bool isSelectionMode;
  final bool isSelected;

  const _RequestGridCard({
    required this.request,
    required this.onTap,
    this.onLongPress,
    this.onDuplicate,
    this.onEdit,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  State<_RequestGridCard> createState() => _RequestGridCardState();
}

class _RequestGridCardState extends State<_RequestGridCard> {
  bool _isHovered = false;
  
  static const Color _cardBackground = Color(0xFF1E1E1E);
  static const Color _hoverBackground = Color(0xFF252525);
  static const Color _badgeBackground = Color(0xFF333333);
  static const Color _subtitleGray = Color(0xFFB0B0B0);
  static const Color _accentGreen = Color(0xFF00E676);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? _accentGreen.withOpacity(0.15) 
                : _isHovered 
                    ? _hoverBackground 
                    : _cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: widget.isSelected 
                ? Border.all(color: _accentGreen, width: 2) 
                : Border.all(color: _isHovered ? Colors.white24 : Colors.transparent),
            boxShadow: _isHovered ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section (top half)
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFF2A2A2A),
                        child: widget.request.imageUrl != null && widget.request.imageUrl!.isNotEmpty
                            ? Image.network(
                                widget.request.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                              )
                            : _buildPlaceholder(),
                      ),
                    ),
                    // Status badge (top right)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.request.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.request.statusLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Selection checkbox (top left)
                    if (widget.isSelectionMode)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isSelected ? _accentGreen : Colors.black54,
                            border: Border.all(
                              color: widget.isSelected ? _accentGreen : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: widget.isSelected
                              ? const Icon(LucideIcons.check, color: Colors.black, size: 14)
                              : null,
                        ),
                      ),
                    // Hover actions (bottom right)
                    if (_isHovered && !widget.isSelectionMode)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Row(
                          children: [
                            if (widget.onEdit != null)
                              _buildActionButton(LucideIcons.pencil, 'Edit', widget.onEdit!),
                            const SizedBox(width: 4),
                            _buildActionButton(LucideIcons.copy, 'Duplicate', widget.onDuplicate ?? () {}),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Info section (bottom half)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request.partName ?? 'Part Request',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.request.vehicleDisplay,
                        style: const TextStyle(color: _subtitleGray, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        widget.request.timeAgo,
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(LucideIcons.image, color: _subtitleGray, size: 40),
    );
  }
  
  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.offered:
        return const Color(0xFF00C853);
      case RequestStatus.accepted:
        return const Color(0xFF2196F3);
      case RequestStatus.fulfilled:
        return const Color(0xFF9C27B0);
      case RequestStatus.cancelled:
        return Colors.red;
      case RequestStatus.expired:
        return Colors.orange;
      case RequestStatus.pending:
      default:
        return _badgeBackground;
    }
  }
}
