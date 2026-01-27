import 'package:flutter/material.dart';

import '../services/haptic_service.dart';

/// Drop-in wrappers for Flutter buttons that automatically trigger haptics.
///
/// Use these in places where we want consistent tactile feedback without
/// repeating the same boilerplate.
class HapticElevatedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final Future<void> Function() haptic;

  const HapticElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.haptic = HapticService.light,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      onPressed: onPressed == null
          ? null
          : () async {
              await haptic();
              onPressed!();
            },
      child: child,
    );
  }
}

class HapticTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final Future<void> Function() haptic;

  const HapticTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.haptic = HapticService.light,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      onPressed: onPressed == null
          ? null
          : () async {
              await haptic();
              onPressed!();
            },
      child: child,
    );
  }
}

class HapticOutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final Future<void> Function() haptic;

  const HapticOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.haptic = HapticService.light,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      onPressed: onPressed == null
          ? null
          : () async {
              await haptic();
              onPressed!();
            },
      child: child,
    );
  }
}
