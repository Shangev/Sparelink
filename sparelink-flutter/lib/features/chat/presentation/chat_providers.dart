import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to track the currently selected chat in master-detail view
/// When a chat is selected from the list, this updates and the detail pane rebuilds
final selectedChatProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

/// Provider to track if we're in desktop master-detail mode
final isDesktopChatModeProvider = StateProvider<bool>((ref) => false);
