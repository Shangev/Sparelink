import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Responsive layout wrapper for authentication screens.
/// 
/// On mobile: Full-width layout (current design)
/// On tablet/desktop: Centered card with max-width, optional branding panel
class AuthResponsiveLayout extends StatelessWidget {
  final Widget child;
  final bool showBackButton;
  final String? title;
  
  /// Breakpoints
  static const double mobileBreakpoint = 600;
  static const double desktopBreakpoint = 1024;
  static const double maxFormWidth = 450;
  
  const AuthResponsiveLayout({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBackButton || title != null
          ? AppBar(
              title: title != null ? Text(title!) : null,
              automaticallyImplyLeading: showBackButton,
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryBlack, AppTheme.darkGray],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= mobileBreakpoint;
              final isLargeDesktop = constraints.maxWidth >= desktopBreakpoint;
              
              if (isLargeDesktop) {
                return _buildLargeDesktopLayout(context, constraints);
              } else if (isDesktop) {
                return _buildDesktopLayout(context, constraints);
              } else {
                return _buildMobileLayout(context);
              }
            },
          ),
        ),
      ),
    );
  }

  /// Mobile layout: Full-width scrollable content
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  /// Desktop layout: Centered card with constrained width
  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: SizedBox(
          width: maxFormWidth,
          child: child,
        ),
      ),
    );
  }

  /// Large desktop layout: Split view with branding panel and form
  Widget _buildLargeDesktopLayout(BuildContext context, BoxConstraints constraints) {
    return Row(
      children: [
        // Left side: Branding panel
        Expanded(
          flex: 5,
          child: _buildBrandingPanel(context),
        ),
        // Right side: Auth form
        Expanded(
          flex: 4,
          child: Container(
            color: AppTheme.darkGray.withOpacity(0.3),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 48),
                child: SizedBox(
                  width: maxFormWidth,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Branding panel for large desktop screens
  Widget _buildBrandingPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlack,
            AppTheme.accentGreen.withOpacity(0.1),
            AppTheme.primaryBlack,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentGreen,
                      AppTheme.accentGreen.withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentGreen.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.build_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              // Brand name
              Text(
                'SpareLink',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              // Tagline
              Text(
                'Auto Parts Marketplace',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.lightGray,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 48),
              // Feature highlights
              _buildFeatureItem(
                context,
                Icons.search,
                'Find Parts Fast',
                'Search thousands of auto parts from local shops',
              ),
              const SizedBox(height: 24),
              _buildFeatureItem(
                context,
                Icons.store,
                'Connect with Shops',
                'Get quotes directly from verified suppliers',
              ),
              const SizedBox(height: 24),
              _buildFeatureItem(
                context,
                Icons.delivery_dining,
                'Quick Delivery',
                'Get parts delivered to your workshop',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 350),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentGreen.withOpacity(0.3),
              ),
            ),
            child: Icon(
              icon,
              color: AppTheme.accentGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
