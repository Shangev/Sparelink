import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Responsive layout wrapper for dashboard pages.
/// Centers content on desktop with max-width constraint.
/// Full-width on mobile.
class ResponsivePageLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;
  final bool showBackButton;
  final String? title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool centerContent;

  /// Standard max-widths for different page types
  static const double narrowWidth = 600;   // For forms, auth pages
  static const double mediumWidth = 800;   // For profile, settings
  static const double wideWidth = 1000;    // For lists, tables
  static const double extraWideWidth = 1200; // For dashboards with multiple columns

  const ResponsivePageLayout({
    super.key,
    required this.child,
    this.maxWidth = mediumWidth,
    this.padding,
    this.showBackButton = false,
    this.title,
    this.actions,
    this.backgroundColor,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFF121212),
      appBar: (showBackButton || title != null || actions != null)
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              title: title != null
                  ? Text(
                      title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
              actions: actions,
              centerTitle: false,
            )
          : null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              const Color(0xFF1A1A1A),
              backgroundColor ?? const Color(0xFF121212),
            ],
          ),
        ),
        child: SafeArea(
          child: isDesktop
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final content = Container(
      width: maxWidth,
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    return SingleChildScrollView(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: centerContent
          ? Center(child: content)
          : content,
    );
  }
}

/// A card container for desktop dashboard sections
class DashboardCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final EdgeInsets? padding;
  final double? width;
  final List<Widget>? actions;

  const DashboardCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.padding,
    this.width,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: AppTheme.accentGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
          ],
          Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Two-column layout for desktop (single column on mobile)
class TwoColumnLayout extends StatelessWidget {
  final Widget leftColumn;
  final Widget rightColumn;
  final double leftFlex;
  final double rightFlex;
  final double spacing;

  const TwoColumnLayout({
    super.key,
    required this.leftColumn,
    required this.rightColumn,
    this.leftFlex = 1,
    this.rightFlex = 2,
    this.spacing = 24,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex.toInt(), child: leftColumn),
          SizedBox(width: spacing),
          Expanded(flex: rightFlex.toInt(), child: rightColumn),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leftColumn,
          SizedBox(height: spacing),
          rightColumn,
        ],
      );
    }
  }
}

/// Grid layout that adapts columns based on screen width
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minChildWidth;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minChildWidth = 300,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minChildWidth).floor().clamp(1, 4);
        final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) => SizedBox(
            width: itemWidth,
            child: child,
          )).toList(),
        );
      },
    );
  }
}
