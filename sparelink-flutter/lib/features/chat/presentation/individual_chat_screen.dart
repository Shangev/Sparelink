import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/services/haptic_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

/// Individual Chat Screen - Conversation with a shop
/// Clean dark-mode design with message bubbles, timestamps, and input field
class IndividualChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final Map<String, dynamic>? chatData;

  const IndividualChatScreen({
    super.key,
    required this.chatId,
    this.chatData,
  });

  @override
  ConsumerState<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends ConsumerState<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Design constants - UX-01 FIX: Use AppTheme colors for consistency
  static const Color _backgroundColor = Color(0xFF000000);  // AppTheme.primaryBlack
  static const Color _cardBackground = Color(0xFF1A1A1A);   // AppTheme.darkGray
  static const Color _userMessageBackground = Color(0xFF2A2A2A); // AppTheme.mediumGray
  static const Color _subtitleGray = Color(0xFF888888);     // AppTheme.lightGray
  static const Color _timestampGray = Color(0xFF666666);    // AppTheme.textHint

  // Real messages from Supabase
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _filteredMessages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  String? _currentUserId;
  RealtimeChannel? _messageSubscription;
  RealtimeChannel? _typingSubscription;
  RealtimeChannel? _onlineStatusSubscription;
  bool _showJumpToTop = false;
  
  // New features state
  bool _isSearchMode = false;
  String _searchQuery = '';
  bool _isTyping = false;
  bool _otherUserTyping = false;
  Timer? _typingTimer;
  String? _editingMessageId;
  Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;
  bool _otherUserOnline = false;
  bool _isRecordingVoice = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _playingMessageId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _updateOnlineStatus(true);
  }
  
  void _onScroll() {
    // Show jump-to-top button when scrolled down more than 200 pixels
    final shouldShow = _scrollController.hasClients && 
                       _scrollController.offset > 200;
    if (shouldShow != _showJumpToTop) {
      setState(() => _showJumpToTop = shouldShow);
    }
  }
  
  void _jumpToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String? _conversationId;  // Track conversation ID for request chats
  
  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storageService = ref.read(storageServiceProvider);
      final supabaseService = ref.read(supabaseServiceProvider);
      
      _currentUserId = await storageService.getUserId();
      
      debugPrint('🔄 [IndividualChatScreen] Loading messages for chatId: ${widget.chatId}');
      debugPrint('👤 [IndividualChatScreen] Current user: $_currentUserId');
      debugPrint('📦 [IndividualChatScreen] Chat data received: ${widget.chatData?.keys.toList()}');
      
      // Chat data might be directly in chatData or nested in 'conversation' key
      Map<String, dynamic>? conversationData = widget.chatData?['conversation'] as Map<String, dynamic>? ?? widget.chatData;
      
      // If chatData is null (GoRouter drops extra data), fetch from database
      if (conversationData == null || conversationData.isEmpty) {
        debugPrint('⚠️ [IndividualChatScreen] No chat data passed (GoRouter dropped extra), fetching from database...');
        
        // Try to fetch from request_chats table first
        try {
          debugPrint('🔍 [IndividualChatScreen] Trying request_chats table with id: ${widget.chatId}');
          final chatResult = await Supabase.instance.client
              .from('request_chats')
              .select('''
                *,
                shops:shop_id(id, name, phone, suburb, rating),
                part_requests:request_id(id, vehicle_make, vehicle_model, vehicle_year, part_category, status, mechanic_id)
              ''')
              .eq('id', widget.chatId)
              .maybeSingle();
          
          if (chatResult != null) {
            conversationData = {
              ...chatResult,
              'type': 'request_chat',
              'request_id': chatResult['request_id'],
              'shop_id': chatResult['shop_id'],
            };
            debugPrint('✅ [IndividualChatScreen] Fetched request_chat data: ${conversationData!.keys.toList()}');
          } else {
            debugPrint('⚠️ [IndividualChatScreen] No request_chat found with id: ${widget.chatId}');
          }
        } catch (e) {
          debugPrint('⚠️ [IndividualChatScreen] Failed to fetch request_chat: $e');
        }
        
        // If still null, try conversations table
        if (conversationData == null || conversationData!.isEmpty) {
          try {
            debugPrint('🔍 [IndividualChatScreen] Trying conversations table with id: ${widget.chatId}');
            final convResult = await Supabase.instance.client
                .from('conversations')
                .select('''
                  *,
                  shops:shop_id(id, name, phone, suburb, rating),
                  profiles:mechanic_id(id, full_name, avatar_url)
                ''')
                .eq('id', widget.chatId)
                .maybeSingle();
            
            if (convResult != null) {
              conversationData = {
                ...convResult,
                'type': 'conversation',
              };
              debugPrint('✅ [IndividualChatScreen] Fetched conversation data: ${conversationData!.keys.toList()}');
            } else {
              debugPrint('⚠️ [IndividualChatScreen] No conversation found with id: ${widget.chatId}');
            }
          } catch (e) {
            debugPrint('⚠️ [IndividualChatScreen] Failed to fetch conversation: $e');
          }
        }
      }
      
      debugPrint('📦 [IndividualChatScreen] Chat data type: ${conversationData?['type']}');
      debugPrint('📦 [IndividualChatScreen] Full chat data keys: ${conversationData?.keys.toList()}');
      
      if (_currentUserId == null) {
        setState(() {
          _error = 'Please log in to view messages';
          _isLoading = false;
        });
        return;
      }

      // Check if this is a request_chat (from chats screen showing request chats)
      final isRequestChat = conversationData?['type'] == 'request_chat' || 
                            conversationData?['request_id'] != null ||
                            conversationData?['part_requests'] != null;
      
      debugPrint('🔍 [IndividualChatScreen] Is request chat: $isRequestChat');
      
      List<Map<String, dynamic>> messages = [];
      
      if (isRequestChat) {
        // For request chats, get/create conversation and load from messages table
        final requestId = conversationData?['request_id'] ?? conversationData?['part_requests']?['id'];
        final shopId = conversationData?['shop_id'] ?? conversationData?['shops']?['id'];
        final mechanicId = conversationData?['part_requests']?['mechanic_id'] ?? _currentUserId;
        
        debugPrint('🔗 [IndividualChatScreen] Request chat - looking for conversation:');
        debugPrint('   - request_id: $requestId');
        debugPrint('   - shop_id: $shopId');
        debugPrint('   - mechanic_id: $mechanicId');
        
        if (requestId != null && shopId != null) {
          // Try to find existing conversation
          final existingConv = await Supabase.instance.client
              .from('conversations')
              .select('id')
              .eq('request_id', requestId)
              .eq('shop_id', shopId)
              .maybeSingle();
          
          debugPrint('🔍 [IndividualChatScreen] Existing conversation: $existingConv');
          
          if (existingConv != null) {
            _conversationId = existingConv['id'];
          } else {
            // Create new conversation
            debugPrint('📝 [IndividualChatScreen] Creating new conversation...');
            final newConv = await Supabase.instance.client
                .from('conversations')
                .insert({
                  'request_id': requestId,
                  'mechanic_id': mechanicId,
                  'shop_id': shopId,
                })
                .select('id')
                .single();
            _conversationId = newConv['id'];
          }
          
          debugPrint('✅ [IndividualChatScreen] Using conversation: $_conversationId');
          
          // Load messages from messages table
          final messagesResponse = await Supabase.instance.client
              .from('messages')
              .select()
              .eq('conversation_id', _conversationId!)
              .order('sent_at', ascending: true);
          
          messages = List<Map<String, dynamic>>.from(messagesResponse);
          debugPrint('📬 [IndividualChatScreen] Messages loaded: ${messages.length}');
        }
      } else {
        // Regular conversation - use the chatId as conversation_id directly
        _conversationId = widget.chatId;
        messages = await supabaseService.getMessages(widget.chatId);
        debugPrint('📬 [IndividualChatScreen] Regular chat messages loaded: ${messages.length}');
      }
      
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Subscribe to new messages
      _subscribeToMessages();
      
      // Subscribe to typing indicator and online status
      _subscribeToTypingStatus();
      _subscribeToOnlineStatus();
      
      // Mark all messages as read AFTER conversation is loaded
      // This clears the unread badge when user opens the chat
      if (_conversationId != null && _currentUserId != null) {
        await _markMessagesAsRead();
      }
      
      // Scroll to bottom after loading
      _scrollToBottom();
    } catch (e, stack) {
      debugPrint('❌ [IndividualChatScreen] Error loading messages: $e');
      debugPrint('Stack: $stack');
      setState(() {
        _error = 'Failed to load messages: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Mark all messages from others as read
  /// This is called when:
  /// 1. Chat screen is first opened (_loadMessages)
  /// 2. New messages arrive while chat is open (_subscribeToMessages)
  /// 
  /// CRITICAL: Uses 'messages' table with 'conversation_id' to match getUnreadCountForChat
  Future<void> _markMessagesAsRead() async {
    if (_conversationId == null || _currentUserId == null) {
      debugPrint('⚠️ [IndividualChatScreen] Cannot mark as read - missing conversationId or userId');
      return;
    }
    
    try {
      debugPrint('📖 [IndividualChatScreen] Marking messages as read for conversation: $_conversationId');
      
      // Direct Supabase call for reliability (bypasses any service caching)
      // Uses 'messages' table which is the SAME table getUnreadCountForChat queries
      final result = await Supabase.instance.client
          .from('messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('conversation_id', _conversationId!)
          .neq('sender_id', _currentUserId!)
          .eq('is_read', false)
          .select('id');
      
      final updatedCount = (result as List).length;
      debugPrint('✅ [IndividualChatScreen] Marked $updatedCount messages as read in messages table');
      
      // Force a state update to trigger any listeners
      if (mounted && updatedCount > 0) {
        setState(() {
          // Update local messages to reflect read status
          for (var message in _messages) {
            if (message['sender_id'] != _currentUserId && message['is_read'] == false) {
              message['is_read'] = true;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ [IndividualChatScreen] Failed to mark messages as read: $e');
      // Don't throw - this is a non-critical operation
    }
  }
  
  void _subscribeToMessages() {
    if (_conversationId == null) {
      debugPrint('⚠️ [IndividualChatScreen] Cannot subscribe - no conversation ID');
      return;
    }
    
    debugPrint('📡 [IndividualChatScreen] Subscribing to messages for conversation: $_conversationId');
    
    final supabaseService = ref.read(supabaseServiceProvider);
    _messageSubscription = supabaseService.subscribeToMessages(
      _conversationId!,
      (newMessage) {
        debugPrint('📨 [IndividualChatScreen] New message received: ${newMessage['id']}');
        // Only add if not already in list (avoid duplicates)
        if (!_messages.any((m) => m['id'] == newMessage['id'])) {
          setState(() {
            _messages.add(newMessage);
          });
          _scrollToBottom();
          
          // Mark the new message as read immediately if it's from the other party
          if (newMessage['sender_id'] != _currentUserId) {
            _markMessagesAsRead();
          }
        }
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageSubscription?.unsubscribe();
    _typingSubscription?.unsubscribe();
    _onlineStatusSubscription?.unsubscribe();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _updateOnlineStatus(false);
    super.dispose();
  }
  
  // ==========================================
  // IMAGE SENDING
  // ==========================================
  
  Future<void> _pickAndSendImage({bool fromCamera = false}) async {
    await HapticService.light();
    try {
      final XFile? image = fromCamera
          ? await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 70)
          : await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      
      if (image == null) return;
      
      setState(() => _isSending = true);
      
      // Upload image to Supabase Storage
      final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final bytes = await image.readAsBytes();
      
      await Supabase.instance.client.storage
          .from('chat-images')
          .uploadBinary(fileName, bytes);
      
      final imageUrl = Supabase.instance.client.storage
          .from('chat-images')
          .getPublicUrl(fileName);
      
      // Send message with image
      await _sendMessageWithAttachment(imageUrl: imageUrl, type: 'image');
      await HapticService.success();
      
    } catch (e) {
      await HapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
  
  // ==========================================
  // FILE ATTACHMENTS
  // ==========================================
  
  Future<void> _pickAndSendFile() async {
    await HapticService.light();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      setState(() => _isSending = true);
      
      final file = result.files.first;
      final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final bytes = file.bytes;
      
      if (bytes == null) {
        throw Exception('Could not read file');
      }
      
      await Supabase.instance.client.storage
          .from('chat-files')
          .uploadBinary(fileName, bytes);
      
      final fileUrl = Supabase.instance.client.storage
          .from('chat-files')
          .getPublicUrl(fileName);
      
      await _sendMessageWithAttachment(
        fileUrl: fileUrl, 
        fileName: file.name,
        type: 'file',
      );
      await HapticService.success();
      
    } catch (e) {
      await HapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send file: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
  
  Future<void> _sendMessageWithAttachment({
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    required String type,
  }) async {
    if (_conversationId == null || _currentUserId == null) return;
    
    try {
      final newMessage = await Supabase.instance.client
          .from('messages')
          .insert({
            'conversation_id': _conversationId,
            'sender_id': _currentUserId,
            'text': type == 'image' ? '📷 Image' : '📎 ${fileName ?? "File"}',
            'message_type': type,
            'attachment_url': imageUrl ?? fileUrl,
            'file_name': fileName,
          })
          .select()
          .single();
      
      setState(() {
        if (!_messages.any((m) => m['id'] == newMessage['id'])) {
          _messages.add(newMessage);
        }
      });
      _scrollToBottom();
    } catch (e) {
      rethrow;
    }
  }
  
  // ==========================================
  // TYPING INDICATOR
  // ==========================================
  
  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _setTypingStatus(true);
    }
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTypingStatus(false);
    });
  }
  
  Future<void> _setTypingStatus(bool isTyping) async {
    if (_conversationId == null || _currentUserId == null) return;
    
    setState(() => _isTyping = isTyping);
    
    try {
      await Supabase.instance.client
          .from('typing_status')
          .upsert({
            'conversation_id': _conversationId,
            'user_id': _currentUserId,
            'is_typing': isTyping,
            'updated_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      // Silently fail - typing indicator is not critical
    }
  }
  
  void _subscribeToTypingStatus() {
    if (_conversationId == null) return;
    
    _typingSubscription = Supabase.instance.client
        .channel('typing_$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            if (data['user_id'] != _currentUserId) {
              setState(() => _otherUserTyping = data['is_typing'] == true);
            }
          },
        )
        .subscribe();
  }
  
  // ==========================================
  // ONLINE STATUS
  // ==========================================
  
  Future<void> _updateOnlineStatus(bool isOnline) async {
    if (_currentUserId == null) return;
    
    try {
      await Supabase.instance.client
          .from('user_presence')
          .upsert({
            'user_id': _currentUserId,
            'is_online': isOnline,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          });
    } catch (e) {
      // Silently fail - presence is not critical
      debugPrint('Failed to update online status: $e');
    }
  }
  
  void _subscribeToOnlineStatus() {
    final shopId = widget.chatData?['shops']?['id'] ?? widget.chatData?['shop_id'];
    if (shopId == null) return;
    
    _onlineStatusSubscription = Supabase.instance.client
        .channel('presence_$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_presence',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: shopId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            setState(() => _otherUserOnline = data['is_online'] == true);
          },
        )
        .subscribe();
    
    // Also fetch initial online status
    _fetchInitialOnlineStatus(shopId);
  }
  
  Future<void> _fetchInitialOnlineStatus(String shopId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_presence')
          .select('is_online, last_seen')
          .eq('user_id', shopId)
          .maybeSingle();
      
      if (response != null && mounted) {
        // Consider online if is_online is true and last_seen is within 5 minutes
        final isOnline = response['is_online'] == true;
        final lastSeen = response['last_seen'] != null 
            ? DateTime.parse(response['last_seen']) 
            : null;
        final isRecent = lastSeen != null && 
            DateTime.now().difference(lastSeen).inMinutes < 5;
        
        setState(() => _otherUserOnline = isOnline && isRecent);
      }
    } catch (e) {
      debugPrint('Failed to fetch online status: $e');
    }
  }
  
  // ==========================================
  // VOICE MESSAGES
  // ==========================================
  
  Future<void> _startVoiceRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _recordingPath = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _recordingPath!,
        );
        
        setState(() {
          _isRecordingVoice = true;
          _recordingDuration = Duration.zero;
        });
        
        // Start duration timer
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _stopVoiceRecording({bool send = true}) async {
    _recordingTimer?.cancel();
    
    try {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecordingVoice = false;
        _recordingDuration = Duration.zero;
      });
      
      if (send && path != null) {
        await _sendVoiceMessage(path);
      }
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
      setState(() {
        _isRecordingVoice = false;
        _recordingDuration = Duration.zero;
      });
    }
  }
  
  Future<void> _cancelVoiceRecording() async {
    await HapticService.selection();
    await _stopVoiceRecording(send: false);
    
    // Delete the recording file
    if (_recordingPath != null) {
      try {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore deletion errors
      }
    }
  }
  
  Future<void> _sendVoiceMessage(String filePath) async {
    await HapticService.light();
    if (_conversationId == null || _currentUserId == null) return;
    
    setState(() => _isSending = true);
    
    try {
      // Upload to Supabase Storage
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await Supabase.instance.client.storage
          .from('chat-voice')
          .uploadBinary(fileName, bytes);
      
      final voiceUrl = Supabase.instance.client.storage
          .from('chat-voice')
          .getPublicUrl(fileName);
      
      // Create message
      final newMessage = await Supabase.instance.client
          .from('messages')
          .insert({
            'conversation_id': _conversationId,
            'sender_id': _currentUserId,
            'text': '🎤 Voice message',
            'message_type': 'voice',
            'attachment_url': voiceUrl,
            'duration_seconds': _recordingDuration.inSeconds,
          })
          .select()
          .single();
      
      setState(() {
        if (!_messages.any((m) => m['id'] == newMessage['id'])) {
          _messages.add(newMessage);
        }
      });
      _scrollToBottom();
      await HapticService.success();
      
      // Clean up local file
      try {
        await file.delete();
      } catch (e) {
        // Ignore deletion errors
      }
    } catch (e) {
      await HapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
  
  Future<void> _playVoiceMessage(String messageId, String url) async {
    try {
      if (_playingMessageId == messageId) {
        // Stop playing
        await _audioPlayer.stop();
        setState(() => _playingMessageId = null);
      } else {
        // Play new message
        setState(() => _playingMessageId = messageId);
        await _audioPlayer.play(UrlSource(url));
        
        // Listen for completion
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() => _playingMessageId = null);
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to play voice message: $e');
      setState(() => _playingMessageId = null);
    }
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  // ==========================================
  // MESSAGE DELETION
  // ==========================================
  
  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBackground,
        title: const Text('Delete Message?', style: TextStyle(color: Colors.white)),
        content: const Text('This message will be deleted for everyone.', style: TextStyle(color: _subtitleGray)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('messages')
            .update({'deleted_at': DateTime.now().toIso8601String(), 'text': '[Message deleted]'})
            .eq('id', messageId)
            .eq('sender_id', _currentUserId!);
        
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            _messages[index]['text'] = '[Message deleted]';
            _messages[index]['deleted_at'] = DateTime.now().toIso8601String();
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
  
  // ==========================================
  // MESSAGE EDITING
  // ==========================================
  
  void _startEditingMessage(Map<String, dynamic> message) {
    setState(() {
      _editingMessageId = message['id'];
      _messageController.text = message['text'] ?? '';
    });
  }
  
  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
  }
  
  Future<void> _saveEditedMessage() async {
    if (_editingMessageId == null || _messageController.text.trim().isEmpty) return;
    
    final newText = _messageController.text.trim();
    
    try {
      await Supabase.instance.client
          .from('messages')
          .update({
            'text': newText,
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _editingMessageId!)
          .eq('sender_id', _currentUserId!);
      
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == _editingMessageId);
        if (index != -1) {
          _messages[index]['text'] = newText;
          _messages[index]['edited_at'] = DateTime.now().toIso8601String();
        }
        _editingMessageId = null;
        _messageController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  // ==========================================
  // MESSAGE REACTIONS
  // ==========================================
  
  Future<void> _addReaction(String messageId, String emoji) async {
    try {
      await Supabase.instance.client
          .from('message_reactions')
          .upsert({
            'message_id': messageId,
            'user_id': _currentUserId,
            'emoji': emoji,
          });
      
      // Update local state
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          final reactions = List<Map<String, dynamic>>.from(_messages[index]['reactions'] ?? []);
          reactions.add({'user_id': _currentUserId, 'emoji': emoji});
          _messages[index]['reactions'] = reactions;
        }
      });
    } catch (e) {
      // Silently fail
    }
  }
  
  void _showReactionPicker(String messageId) {
    HapticService.selection();
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBackground,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: emojis.map((emoji) => GestureDetector(
            onTap: () async {
              await HapticService.selection();
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _addReaction(messageId, emoji);
            },
            child: Text(emoji, style: const TextStyle(fontSize: 32)),
          )).toList(),
        ),
      ),
    );
  }
  
  // ==========================================
  // MESSAGE SEARCH
  // ==========================================
  
  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchQuery = '';
        _searchController.clear();
        _filteredMessages = _messages;
      }
    });
  }
  
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredMessages = _messages;
      } else {
        _filteredMessages = _messages.where((m) {
          final text = (m['text'] as String? ?? '').toLowerCase();
          return text.contains(_searchQuery);
        }).toList();
      }
    });
  }
  
  // ==========================================
  // BLOCK/REPORT USER
  // ==========================================
  
  void _showBlockReportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.flag, color: Colors.orange),
              title: const Text('Report User', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Report inappropriate behavior', style: TextStyle(color: _subtitleGray, fontSize: 12)),
              onTap: () async {
                await HapticService.selection();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _reportUser();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.ban, color: Colors.red),
              title: const Text('Block User', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Stop receiving messages from this user', style: TextStyle(color: _subtitleGray, fontSize: 12)),
              onTap: () async {
                await HapticService.selection();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _blockUser();
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _subtitleGray)),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _reportUser() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _ReportDialog(),
    );
    
    if (reason != null && reason.isNotEmpty) {
      try {
        final shopId = widget.chatData?['shops']?['id'] ?? widget.chatData?['shop_id'];
        
        await Supabase.instance.client.from('user_reports').insert({
          'reporter_id': _currentUserId,
          'reported_user_id': shopId,
          'conversation_id': _conversationId,
          'reason': reason,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted. We will review it shortly.'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
  
  Future<void> _blockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBackground,
        title: const Text('Block User?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will no longer receive messages from this shop. You can unblock them later from settings.',
          style: TextStyle(color: _subtitleGray),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final shopId = widget.chatData?['shops']?['id'] ?? widget.chatData?['shop_id'];
        
        await Supabase.instance.client.from('blocked_users').insert({
          'blocker_id': _currentUserId,
          'blocked_id': shopId,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User blocked'), backgroundColor: Colors.red),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to block user: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
  
  // ==========================================
  // CHAT ARCHIVE
  // ==========================================
  
  Future<void> _archiveChat() async {
    await HapticService.selection();
    try {
      await Supabase.instance.client
          .from('conversations')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', _conversationId!);
      
      if (mounted) {
        await HapticService.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat archived'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      await HapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    // Tap haptic (send)
    await HapticService.light();
    
    if (_conversationId == null) {
      debugPrint('❌ [IndividualChatScreen] Cannot send - no conversation ID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat not ready. Please try again.'), backgroundColor: Colors.red),
      );
      return;
    }
    
    final messageText = _messageController.text.trim();
    _messageController.clear();
    
    setState(() => _isSending = true);
    
    debugPrint('📤 [IndividualChatScreen] Sending message to conversation: $_conversationId');
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      
      final newMessage = await supabaseService.sendMessage(
        conversationId: _conversationId!,
        senderId: _currentUserId!,
        text: messageText,
      );
      
      debugPrint('✅ [IndividualChatScreen] Message sent: ${newMessage['id']}');
      await HapticService.success();
      
      // Add to local list immediately for responsiveness
      setState(() {
        if (!_messages.any((m) => m['id'] == newMessage['id'])) {
          _messages.add(newMessage);
        }
      });
      
      _scrollToBottom();
    } catch (e) {
      await HapticService.error();
      debugPrint('❌ [IndividualChatScreen] Failed to send message: $e');
      // Show error and restore message to input
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        _messageController.text = messageText;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      // Parse as UTC and convert to local time for display
      final utcDate = DateTime.parse(timestamp);
      final localDate = utcDate.toLocal();
      final now = DateTime.now();
      final isToday = localDate.year == now.year && localDate.month == now.month && localDate.day == now.day;
      
      if (isToday) {
        return '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
      } else {
        return '${localDate.day}/${localDate.month} ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  bool _isCurrentUser(Map<String, dynamic> message) {
    return message['sender_id'] == _currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final shopName = widget.chatData?['name'] as String? ?? 'Shop';
    final avatarColor = widget.chatData?['avatarColor'] as Color? ?? Colors.blue;
    final status = widget.chatData?['status'] as String? ?? 'Online';

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with shop info
            _buildHeader(shopName, avatarColor, status),
            
            // Messages list with floating Jump to Top button
            // Request Card is now the first scrollable item inside the ListView
            Expanded(
              child: Stack(
                children: [
                  _buildMessagesList(),
                  
                  // Jump to Top button - shows when scrolled down
                  if (_showJumpToTop)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: _jumpToTop,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.arrowUp,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Input field
            _buildInputField(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRequestCard() {
    // Get conversation data - might be nested or direct
    final conversationData = widget.chatData?['conversation'] as Map<String, dynamic>? ?? widget.chatData!;
    
    final quoteAmount = conversationData['quote_amount'];
    final deliveryFee = conversationData['delivery_fee'];
    final chatStatus = conversationData['status'] as String? ?? 'pending';
    final shop = conversationData['shops'] as Map<String, dynamic>?;
    final request = conversationData['part_requests'] as Map<String, dynamic>?;
    final requestId = conversationData['request_id'] ?? request?['id'];
    
    // Format price
    String formatPrice(dynamic cents) {
      if (cents == null) return '—';
      final rands = (cents as num) / 100;
      return 'R ${rands.toStringAsFixed(2)}';
    }
    
    // Calculate total
    final total = (quoteAmount ?? 0) + (deliveryFee ?? 0);
    
    // Status colors
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (chatStatus) {
      case 'quoted':
        statusColor = Colors.blue;
        statusText = 'Quote Received';
        statusIcon = LucideIcons.tag;
        break;
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'Accepted';
        statusIcon = LucideIcons.check;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Declined';
        statusIcon = LucideIcons.x;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Awaiting Quote';
        statusIcon = LucideIcons.clock;
    }
    
    return GestureDetector(
      onTap: () {
        // Navigate to request details
        if (requestId != null) {
          context.push('/my-requests');  // Navigate to requests list where user can see full details
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),  // Only bottom margin since ListView has padding
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge and shop name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (shop != null)
                Text(
                  shop['name'] ?? 'Shop',
                  style: const TextStyle(color: _subtitleGray, fontSize: 12),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Vehicle info
          if (request != null) ...[
            Text(
              '${request['vehicle_year']} ${request['vehicle_make']} ${request['vehicle_model']}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              request['part_category'] ?? 'Part Request',
              style: const TextStyle(color: _subtitleGray, fontSize: 14),
            ),
          ],
          
          // Quote details (only if quoted)
          if (chatStatus == 'quoted' || chatStatus == 'accepted') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Part Price:', style: TextStyle(color: _subtitleGray, fontSize: 14)),
                      Text(formatPrice(quoteAmount), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery:', style: TextStyle(color: _subtitleGray, fontSize: 14)),
                      Text(formatPrice(deliveryFee), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  const Divider(color: Color(0xFF3A3A3A), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(formatPrice(total), style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          // Accept button (only for quoted status)
          if (chatStatus == 'quoted') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptQuote(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Accept Quote', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          
          // Tap hint
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.externalLink, color: _subtitleGray, size: 12),
              SizedBox(width: 4),
              Text('Tap to view full request', style: TextStyle(color: _subtitleGray, fontSize: 11)),
            ],
          ),
        ],
        ),
      ),
    );
  }
  
  Future<void> _acceptQuote() async {
    final chatData = widget.chatData;
    if (chatData == null) return;
    
    try {
      // Get the request_chat ID and update its status
      final requestChatId = chatData['id'];
      final requestId = chatData['part_requests']?['id'];
      final shopId = chatData['shops']?['id'];
      
      // Update request_chats status to accepted
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'accepted'})
          .eq('id', requestChatId);
      
      // Reject other chats for same request
      await Supabase.instance.client
          .from('request_chats')
          .update({'status': 'rejected'})
          .eq('request_id', requestId)
          .neq('id', requestChatId);
      
      // Update part_request status
      await Supabase.instance.client
          .from('part_requests')
          .update({'status': 'accepted', 'accepted_shop_id': shopId})
          .eq('id', requestId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote accepted! The shop will prepare your order.'), backgroundColor: Colors.green),
        );
        // Refresh the screen
        setState(() {
          widget.chatData?['status'] = 'accepted';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept quote: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildHeader(String shopName, Color avatarColor, String status) {
    // Search mode header
    if (_isSearchMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: _backgroundColor,
          border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _toggleSearchMode,
              child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: _subtitleGray),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              Text('${_filteredMessages.length} found', style: const TextStyle(color: _subtitleGray, fontSize: 12)),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _backgroundColor,
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          
          // Avatar with online indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor,
                child: Text(
                  shopName.isNotEmpty ? shopName.split(' ').last[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _otherUserOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: _backgroundColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          
          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    if (_otherUserTyping)
                      const Text('typing...', style: TextStyle(color: Colors.green, fontSize: 13, fontStyle: FontStyle.italic))
                    else
                      Text(
                        _otherUserOnline ? 'Online' : 'Offline',
                        style: TextStyle(color: _otherUserOnline ? Colors.green : _subtitleGray, fontSize: 13),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Search button
          GestureDetector(
            onTap: _toggleSearchMode,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(LucideIcons.search, color: _subtitleGray, size: 22),
            ),
          ),
          
          // More options menu
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.ellipsisVertical, color: _subtitleGray, size: 22),
            color: _cardBackground,
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'archive', child: Row(children: [
                Icon(LucideIcons.archive, size: 18, color: Colors.white),
                SizedBox(width: 12),
                Text('Archive Chat', style: TextStyle(color: Colors.white)),
              ])),
              const PopupMenuItem(value: 'block', child: Row(children: [
                Icon(LucideIcons.ban, size: 18, color: Colors.orange),
                SizedBox(width: 12),
                Text('Block/Report', style: TextStyle(color: Colors.orange)),
              ])),
            ],
            onSelected: (value) {
              if (value == 'archive') _archiveChat();
              if (value == 'block') _showBlockReportDialog();
            },
          ),
        ],
      ),
    );
  }

  /// Check if this is a request chat (for showing request card)
  bool get _isRequestChat {
    final conversationData = widget.chatData?['conversation'] as Map<String, dynamic>? ?? widget.chatData;
    return widget.chatData?['type'] == 'request_chat' || 
           conversationData?['type'] == 'request_chat' ||
           conversationData?['request_id'] != null ||
           conversationData?['part_requests'] != null;
  }
  
  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.circleAlert, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: _subtitleGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Calculate total items: Request Card (if applicable) + messages
    final hasRequestCard = _isRequestChat;
    final itemCount = _messages.length + (hasRequestCard ? 1 : 0);

    if (_messages.isEmpty && !hasRequestCard) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.messageCircle, color: _subtitleGray, size: 48),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(color: _subtitleGray, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // First item: Request Card (if this is a request chat)
        if (hasRequestCard && index == 0) {
          return _buildRequestCard();
        }
        
        // Adjust index for messages when request card is present
        final messageIndex = hasRequestCard ? index - 1 : index;
        final message = _messages[messageIndex];
        final isUser = _isCurrentUser(message);
        
        return _MessageBubble(
          text: message['text'] as String? ?? '',
          time: _formatTime(message['sent_at'] as String?),
          isUser: isUser,
        );
      },
    );
  }

  Widget _buildInputField() {
    // Editing mode UI
    if (_editingMessageId != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: _backgroundColor,
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.pencil, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  const Text('Editing message', style: TextStyle(color: Colors.blue, fontSize: 13)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelEditing,
                    child: const Icon(LucideIcons.x, color: Colors.blue, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: _cardBackground, borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Edit message...',
                        hintStyle: TextStyle(color: _subtitleGray),
                      ),
                      autofocus: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _saveEditedMessage,
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.check, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: _backgroundColor,
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
      ),
      child: Column(
        children: [
          // Typing indicator from other user
          if (_otherUserTyping)
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypingDots(),
                        const SizedBox(width: 8),
                        const Text('typing...', style: TextStyle(color: _subtitleGray, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.plus, color: _subtitleGray, size: 24),
                color: _cardBackground,
                offset: const Offset(0, -180),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'camera', child: Row(children: [
                    Icon(LucideIcons.camera, size: 18, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Take Photo', style: TextStyle(color: Colors.white)),
                  ])),
                  const PopupMenuItem(value: 'gallery', child: Row(children: [
                    Icon(LucideIcons.image, size: 18, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Photo from Gallery', style: TextStyle(color: Colors.white)),
                  ])),
                  const PopupMenuItem(value: 'file', child: Row(children: [
                    Icon(LucideIcons.file, size: 18, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Document', style: TextStyle(color: Colors.white)),
                  ])),
                ],
                onSelected: (value) {
                  if (value == 'camera') _pickAndSendImage(fromCamera: true);
                  if (value == 'gallery') _pickAndSendImage(fromCamera: false);
                  if (value == 'file') _pickAndSendFile();
                },
              ),
              
              // Text input
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: _cardBackground, borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: _subtitleGray),
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Voice recording or Send button
              if (_isRecordingVoice)
                // Recording controls
                Row(
                  children: [
                    // Cancel recording
                    GestureDetector(
                      onTap: () async {
                        await HapticService.selection();
                        await _cancelVoiceRecording();
                      },
                      child: Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.x, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Recording duration
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatDuration(_recordingDuration), style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send recording
                    GestureDetector(
                      onTap: () async {
                        await HapticService.light();
                        await _stopVoiceRecording();
                      },
                      child: Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.send, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                )
              else if (_messageController.text.trim().isEmpty)
                // Microphone button (when no text)
                GestureDetector(
                  onTap: () async {
                    await HapticService.light();
                    await _startVoiceRecording();
                  },
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.mic, color: Colors.black, size: 22),
                  ),
                )
              else
                // Send button (when there's text)
                GestureDetector(
                  onTap: _isSending
                      ? null
                      : () async {
                          await _sendMessage();
                        },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _isSending ? Colors.grey : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.send, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTypingDots() {
    return Row(
      children: List.generate(3, (i) => Container(
        margin: EdgeInsets.only(right: i < 2 ? 3 : 0),
        width: 6, height: 6,
        decoration: const BoxDecoration(color: _subtitleGray, shape: BoxShape.circle),
      )),
    );
  }
}

/// Report Dialog
class _ReportDialog extends StatefulWidget {
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  
  final _reasons = [
    'Spam or scam',
    'Inappropriate content',
    'Harassment or bullying',
    'Fake shop/business',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Report User', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this user?', style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14)),
            const SizedBox(height: 12),
            ...(_reasons.map((reason) => RadioListTile<String>(
              title: Text(reason, style: const TextStyle(color: Colors.white, fontSize: 14)),
              value: reason,
              groupValue: _selectedReason,
              activeColor: Colors.orange,
              onChanged: (v) => setState(() => _selectedReason = v),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ))),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Additional details (optional)',
                hintStyle: const TextStyle(color: Color(0xFF808080)),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null ? null : () {
            Navigator.pop(context, '$_selectedReason: ${_detailsController.text}');
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Submit Report'),
        ),
      ],
    );
  }
}

/// Message Bubble Widget
class _MessageBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isUser;

  static const Color _userMessageBackground = Color(0xFF333333);
  static const Color _shopMessageBackground = Color(0xFF1E1E1E);
  static const Color _timestampGray = Color(0xFF808080);

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? _userMessageBackground : _shopMessageBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                color: _timestampGray,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
