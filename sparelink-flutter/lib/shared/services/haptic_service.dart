import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized haptic management.
///
/// Note: Flutter web does not support haptics, so all methods no-op on web.
class HapticService {
  const HapticService._();

  static bool get _enabled => !kIsWeb;

  /// Light haptic feedback for taps (buttons, icon taps).
  static Future<void> light() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Selection haptic feedback for toggles, list selection, segmented controls.
  static Future<void> selection() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Medium haptic feedback for successful actions.
  static Future<void> success() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy haptic feedback for errors/warnings.
  static Future<void> error() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// A slightly richer success pattern (medium -> light).
  static Future<void> successPattern() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }
}
