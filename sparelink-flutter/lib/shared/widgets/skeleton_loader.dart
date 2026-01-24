import 'package:flutter/material.dart';

/// Skeleton Loader Widget
/// 
/// Provides shimmer/skeleton loading effects for better UX
/// while content is being fetched.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;
  
  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
    this.isCircle = false,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle ? null : BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: const [
                Color(0xFF2A2A2A),
                Color(0xFF3A3A3A),
                Color(0xFF2A2A2A),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton card for the home screen grid
class SkeletonGridCard extends StatelessWidget {
  const SkeletonGridCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SkeletonLoader(width: 48, height: 48, borderRadius: 12),
          SizedBox(height: 16),
          SkeletonLoader(height: 20, width: 100),
          SizedBox(height: 8),
          SkeletonLoader(height: 14, width: 140),
          SizedBox(height: 4),
          SkeletonLoader(height: 14, width: 120),
        ],
      ),
    );
  }
}

/// Skeleton for stats card
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonLoader(height: 32, width: 50),
          SizedBox(height: 8),
          SkeletonLoader(height: 14, width: 80),
        ],
      ),
    );
  }
}

/// Skeleton for recent activity item
class SkeletonActivityItem extends StatelessWidget {
  const SkeletonActivityItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 40, height: 40, isCircle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(height: 16, width: 150),
                SizedBox(height: 6),
                SkeletonLoader(height: 12, width: 100),
              ],
            ),
          ),
          const SkeletonLoader(width: 60, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Skeleton for search bar
class SkeletonSearchBar extends StatelessWidget {
  const SkeletonSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: const [
          SizedBox(width: 16),
          SkeletonLoader(width: 24, height: 24, borderRadius: 4),
          SizedBox(width: 12),
          Expanded(child: SkeletonLoader(height: 16)),
          SizedBox(width: 16),
        ],
      ),
    );
  }
}

/// Skeleton for request list item (My List screen)
class SkeletonRequestCard extends StatelessWidget {
  const SkeletonRequestCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder
          const SkeletonLoader(width: 60, height: 60, borderRadius: 8),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(height: 16, width: 140),
                SizedBox(height: 8),
                SkeletonLoader(height: 13, width: 100),
                SizedBox(height: 4),
                SkeletonLoader(height: 12, width: 70),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge placeholder
          const SkeletonLoader(width: 70, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Skeleton for notification item
class SkeletonNotificationItem extends StatelessWidget {
  const SkeletonNotificationItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 44, height: 44, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(height: 14, width: 180),
                SizedBox(height: 6),
                SkeletonLoader(height: 12, width: 120),
              ],
            ),
          ),
          const SkeletonLoader(width: 50, height: 12),
        ],
      ),
    );
  }
}

/// Skeleton for chat list item
class SkeletonChatItem extends StatelessWidget {
  const SkeletonChatItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 50, height: 50, isCircle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(height: 16, width: 140),
                SizedBox(height: 6),
                SkeletonLoader(height: 13, width: 200),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              SkeletonLoader(width: 40, height: 10),
              SizedBox(height: 8),
              SkeletonLoader(width: 20, height: 20, isCircle: true),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pass 3 FIX: Skeleton for request card with offer counts
/// Used when loading data from part_requests_with_counts view
/// Shows placeholder for offer count badge to prevent "jumpy" UI
class SkeletonRequestCardWithCounts extends StatelessWidget {
  const SkeletonRequestCardWithCounts({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Image + Vehicle info + Status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Part image placeholder
              const SkeletonLoader(width: 72, height: 72, borderRadius: 12),
              const SizedBox(width: 12),
              // Vehicle and part info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    // Part name
                    SkeletonLoader(height: 18, width: 160),
                    SizedBox(height: 8),
                    // Vehicle info
                    SkeletonLoader(height: 14, width: 120),
                    SizedBox(height: 4),
                    // Time ago
                    SkeletonLoader(height: 12, width: 60),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge placeholder
              const SkeletonLoader(width: 80, height: 28, borderRadius: 14),
            ],
          ),
          const SizedBox(height: 16),
          // Bottom row: Offer counts from view
          Row(
            children: [
              // Shops contacted count
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      SkeletonLoader(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 8),
                      SkeletonLoader(height: 12, width: 70),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Quotes received count (from view)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      SkeletonLoader(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 8),
                      SkeletonLoader(height: 12, width: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pass 3 FIX: Skeleton list for multiple request cards with counts
/// Use this when loading the My Requests screen
class SkeletonRequestListWithCounts extends StatelessWidget {
  final int itemCount;
  
  const SkeletonRequestListWithCounts({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonRequestCardWithCounts(),
    );
  }
}
