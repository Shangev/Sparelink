import 'package:flutter/material.dart';

// =============================================================================
// SEMANTIC WIDGETS FOR ACCESSIBILITY
// Pass 2 Phase 5 Implementation
// Provides widgets with proper semantic labels for screen readers
// =============================================================================

/// A card wrapper with semantic grouping
class SemanticCard extends StatelessWidget {
  final Widget child;
  final String label;
  final String? hint;
  final VoidCallback? onTap;
  final bool excludeSemantics;
  
  const SemanticCard({
    super.key,
    required this.child,
    required this.label,
    this.hint,
    this.onTap,
    this.excludeSemantics = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: onTap != null,
      enabled: onTap != null,
      excludeSemantics: excludeSemantics,
      child: onTap != null
          ? GestureDetector(onTap: onTap, child: child)
          : child,
    );
  }
}

/// A list item with semantic grouping
class SemanticListItem extends StatelessWidget {
  final Widget child;
  final String label;
  final String? value;
  final String? hint;
  final VoidCallback? onTap;
  final int? index;
  final int? total;
  
  const SemanticListItem({
    super.key,
    required this.child,
    required this.label,
    this.value,
    this.hint,
    this.onTap,
    this.index,
    this.total,
  });
  
  @override
  Widget build(BuildContext context) {
    String fullLabel = label;
    if (value != null) {
      fullLabel = '$label: $value';
    }
    if (index != null && total != null) {
      fullLabel = '$fullLabel, item ${index! + 1} of $total';
    }
    
    return Semantics(
      label: fullLabel,
      hint: hint ?? (onTap != null ? 'Double tap to open' : null),
      button: onTap != null,
      child: onTap != null
          ? InkWell(onTap: onTap, child: child)
          : child,
    );
  }
}

/// A status badge with semantic label
class SemanticStatusBadge extends StatelessWidget {
  final Widget child;
  final String status;
  final String? context;
  
  const SemanticStatusBadge({
    super.key,
    required this.child,
    required this.status,
    this.context,
  });
  
  @override
  Widget build(BuildContext context_) {
    final label = context != null 
        ? '$context status: $status'
        : 'Status: $status';
    
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// A price display with semantic label
class SemanticPrice extends StatelessWidget {
  final Widget child;
  final int priceInCents;
  final String currency;
  final String? context;
  
  const SemanticPrice({
    super.key,
    required this.child,
    required this.priceInCents,
    this.currency = 'R',
    this.context,
  });
  
  @override
  Widget build(BuildContext context_) {
    final priceText = '${(priceInCents / 100).toStringAsFixed(2)} ${currency == 'R' ? 'Rands' : currency}';
    final label = context != null ? '$context: $priceText' : priceText;
    
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// A count/badge with semantic label
class SemanticCount extends StatelessWidget {
  final Widget child;
  final int count;
  final String itemType;
  final bool isUnread;
  
  const SemanticCount({
    super.key,
    required this.child,
    required this.count,
    required this.itemType,
    this.isUnread = false,
  });
  
  @override
  Widget build(BuildContext context) {
    String label;
    if (count == 0) {
      label = isUnread ? 'No unread $itemType' : 'No $itemType';
    } else if (count == 1) {
      label = isUnread ? '1 unread ${itemType.replaceAll('s', '')}' : '1 ${itemType.replaceAll('s', '')}';
    } else {
      label = isUnread ? '$count unread $itemType' : '$count $itemType';
    }
    
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// A timestamp with semantic label
class SemanticTimestamp extends StatelessWidget {
  final Widget child;
  final DateTime dateTime;
  final String? prefix;
  
  const SemanticTimestamp({
    super.key,
    required this.child,
    required this.dateTime,
    this.prefix,
  });
  
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    String timeText;
    if (difference.inMinutes < 1) {
      timeText = 'Just now';
    } else if (difference.inMinutes < 60) {
      timeText = '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      timeText = '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      timeText = 'Yesterday';
    } else if (difference.inDays < 7) {
      timeText = '${difference.inDays} days ago';
    } else {
      timeText = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    
    final label = prefix != null ? '$prefix $timeText' : timeText;
    
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// An image with semantic description
class SemanticImage extends StatelessWidget {
  final Widget child;
  final String description;
  final bool isDecorative;
  
  const SemanticImage({
    super.key,
    required this.child,
    required this.description,
    this.isDecorative = false,
  });
  
  @override
  Widget build(BuildContext context) {
    if (isDecorative) {
      return ExcludeSemantics(child: child);
    }
    
    return Semantics(
      image: true,
      label: description,
      child: child,
    );
  }
}

/// A heading with proper semantic level
class SemanticHeading extends StatelessWidget {
  final Widget child;
  final String text;
  final bool isHeader;
  
  const SemanticHeading({
    super.key,
    required this.child,
    required this.text,
    this.isHeader = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: isHeader,
      label: text,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// A form field wrapper with semantic label
class SemanticFormField extends StatelessWidget {
  final Widget child;
  final String label;
  final String? value;
  final String? error;
  final bool isRequired;
  
  const SemanticFormField({
    super.key,
    required this.child,
    required this.label,
    this.value,
    this.error,
    this.isRequired = false,
  });
  
  @override
  Widget build(BuildContext context) {
    String fullLabel = label;
    if (isRequired) {
      fullLabel = '$label, required';
    }
    if (value != null && value!.isNotEmpty) {
      fullLabel = '$fullLabel, current value: $value';
    }
    if (error != null) {
      fullLabel = '$fullLabel, error: $error';
    }
    
    return Semantics(
      label: fullLabel,
      textField: true,
      child: child,
    );
  }
}

/// A toggle/switch with semantic label
class SemanticToggle extends StatelessWidget {
  final Widget child;
  final String label;
  final bool isOn;
  final String? hint;
  
  const SemanticToggle({
    super.key,
    required this.child,
    required this.label,
    required this.isOn,
    this.hint,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: isOn,
      hint: hint ?? 'Double tap to ${isOn ? 'disable' : 'enable'}',
      child: child,
    );
  }
}

/// A loading indicator with semantic label
class SemanticLoading extends StatelessWidget {
  final Widget child;
  final String? message;
  
  const SemanticLoading({
    super.key,
    required this.child,
    this.message,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message ?? 'Loading, please wait',
      liveRegion: true,
      child: child,
    );
  }
}

/// An error message with semantic label
class SemanticError extends StatelessWidget {
  final Widget child;
  final String message;
  final VoidCallback? onRetry;
  
  const SemanticError({
    super.key,
    required this.child,
    required this.message,
    this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Error: $message${onRetry != null ? '. Double tap to retry.' : ''}',
      liveRegion: true,
      child: child,
    );
  }
}

/// A navigation tab with semantic label
class SemanticNavTab extends StatelessWidget {
  final Widget child;
  final String label;
  final bool isSelected;
  final int index;
  final int total;
  
  const SemanticNavTab({
    super.key,
    required this.child,
    required this.label,
    required this.isSelected,
    required this.index,
    required this.total,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, tab ${index + 1} of $total${isSelected ? ', selected' : ''}',
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: child,
    );
  }
}

/// Announce a message to screen readers
class ScreenReaderAnnouncement extends StatelessWidget {
  final Widget child;
  final String message;
  final bool assertive;
  
  const ScreenReaderAnnouncement({
    super.key,
    required this.child,
    required this.message,
    this.assertive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: child,
    );
  }
}

/// Extension to easily add semantics to any widget
extension SemanticExtension on Widget {
  /// Wrap with a semantic label
  Widget withSemantics(String label, {String? hint, bool? button}) {
    return Semantics(
      label: label,
      hint: hint,
      button: button,
      child: this,
    );
  }
  
  /// Mark as decorative (excluded from semantics)
  Widget asDecorative() {
    return ExcludeSemantics(child: this);
  }
  
  /// Mark as a live region (announces changes)
  Widget asLiveRegion(String label) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: this,
    );
  }
}
