import 'package:flutter/material.dart';

import '../services/haptic_service.dart';

/// Wraps any tappable child and triggers haptics before executing [onTap].
///
/// Use this for GestureDetector/InkWell areas where we want consistent haptics.
class HapticTap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final Future<void> Function() haptic;
  final HitTestBehavior behavior;

  const HapticTap({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.haptic = HapticService.light,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onTap: (!enabled || onTap == null)
          ? null
          : () async {
              await haptic();
              onTap!();
            },
      child: child,
    );
  }
}
