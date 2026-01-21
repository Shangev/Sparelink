import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// UX Service for haptic feedback, app rating, and onboarding
class UxService {
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String _keyRequestCount = 'successful_request_count';
  static const String _keyHasRatedApp = 'has_rated_app';
  static const String _keyLastRatingPrompt = 'last_rating_prompt';
  
  // ============================================
  // HAPTIC FEEDBACK
  // ============================================
  
  /// Light haptic feedback for button taps
  static Future<void> lightHaptic() async {
    if (kIsWeb) return; // No haptics on web
    await HapticFeedback.lightImpact();
  }
  
  /// Medium haptic feedback for successful actions
  static Future<void> mediumHaptic() async {
    if (kIsWeb) return;
    await HapticFeedback.mediumImpact();
  }
  
  /// Heavy haptic feedback for important confirmations
  static Future<void> heavyHaptic() async {
    if (kIsWeb) return;
    await HapticFeedback.heavyImpact();
  }
  
  /// Success haptic pattern (used for successful submissions)
  static Future<void> successHaptic() async {
    if (kIsWeb) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }
  
  /// Error haptic pattern
  static Future<void> errorHaptic() async {
    if (kIsWeb) return;
    await HapticFeedback.heavyImpact();
  }
  
  /// Selection changed haptic
  static Future<void> selectionHaptic() async {
    if (kIsWeb) return;
    await HapticFeedback.selectionClick();
  }
  
  // ============================================
  // ONBOARDING
  // ============================================
  
  /// Check if user has completed onboarding
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }
  
  /// Mark onboarding as completed
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, true);
  }
  
  /// Reset onboarding (for testing)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, false);
  }
  
  // ============================================
  // APP RATING PROMPT
  // ============================================
  
  /// Increment successful request count
  static Future<void> incrementRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keyRequestCount) ?? 0;
    await prefs.setInt(_keyRequestCount, count + 1);
  }
  
  /// Check if we should show rating prompt
  /// Shows after 3 successful requests, then every 10 requests
  /// Won't show more than once per week
  static Future<bool> shouldShowRatingPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Already rated? Don't show again
    if (prefs.getBool(_keyHasRatedApp) ?? false) {
      return false;
    }
    
    final count = prefs.getInt(_keyRequestCount) ?? 0;
    
    // Show after 3 requests initially, then every 10
    if (count < 3) return false;
    if (count > 3 && (count - 3) % 10 != 0) return false;
    
    // Check if we showed recently (within 7 days)
    final lastPrompt = prefs.getString(_keyLastRatingPrompt);
    if (lastPrompt != null) {
      final lastDate = DateTime.tryParse(lastPrompt);
      if (lastDate != null) {
        final daysSince = DateTime.now().difference(lastDate).inDays;
        if (daysSince < 7) return false;
      }
    }
    
    return true;
  }
  
  /// Record that rating prompt was shown
  static Future<void> recordRatingPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastRatingPrompt, DateTime.now().toIso8601String());
  }
  
  /// Record that user rated the app (or chose "never ask again")
  static Future<void> recordAppRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRatedApp, true);
  }
}

// ============================================
// ACCESSIBILITY HELPERS
// ============================================

/// Semantic wrapper for better screen reader support
class AccessibleWidget extends StatelessWidget {
  final Widget child;
  final String label;
  final String? hint;
  final String? value;
  final bool isButton;
  final bool isHeader;
  final bool isLink;
  final bool excludeSemantics;
  final VoidCallback? onTap;

  const AccessibleWidget({
    super.key,
    required this.child,
    required this.label,
    this.hint,
    this.value,
    this.isButton = false,
    this.isHeader = false,
    this.isLink = false,
    this.excludeSemantics = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (excludeSemantics) {
      return ExcludeSemantics(child: child);
    }
    
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton,
      header: isHeader,
      link: isLink,
      onTap: onTap,
      child: child,
    );
  }
}

/// High contrast color palette for accessibility
class AccessibleColors {
  // These meet WCAG AA contrast requirements against black background
  static const Color textPrimary = Color(0xFFFFFFFF);      // White - 21:1
  static const Color textSecondary = Color(0xFFB3B3B3);    // Light grey - 7.5:1
  static const Color textMuted = Color(0xFF8C8C8C);        // Grey - 4.5:1 (minimum AA)
  static const Color accentGreen = Color(0xFF00E676);      // Bright green - 8.2:1
  static const Color accentGreenDark = Color(0xFF00C853);  // Darker green - 6.8:1
  static const Color error = Color(0xFFFF5252);            // Red - 5.1:1
  static const Color warning = Color(0xFFFFAB40);          // Orange - 6.3:1
  static const Color info = Color(0xFF40C4FF);             // Blue - 6.1:1
  
  // Background colors
  static const Color surfaceLight = Color(0xFF1A1A1A);     // Slight contrast from black
  static const Color surfaceMedium = Color(0xFF2D2D2D);    // Card backgrounds
  static const Color surfaceDark = Color(0xFF0D0D0D);      // Darker elements
}

/// Extension for accessible text styles
extension AccessibleTextStyles on TextTheme {
  // Minimum 16sp for body text per accessibility guidelines
  TextStyle get accessibleBody => const TextStyle(
    fontSize: 16,
    color: AccessibleColors.textPrimary,
    height: 1.5, // Good line height for readability
  );
  
  TextStyle get accessibleBodySecondary => const TextStyle(
    fontSize: 16,
    color: AccessibleColors.textSecondary,
    height: 1.5,
  );
  
  // Minimum touch target: 48x48dp
  static const double minTouchTarget = 48.0;
}
