import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/environment_config.dart';

/// Audit Logging Service Provider
final auditLoggerProvider = Provider<AuditLoggingService>((ref) {
  return AuditLoggingService();
});

/// Audit event types for categorization
enum AuditEventType {
  // Authentication events
  authLogin,
  authLogout,
  authRegister,
  authPasswordReset,
  authOtpRequest,
  authOtpVerify,
  
  // User profile events
  profileCreate,
  profileUpdate,
  profileDelete,
  
  // Part request events
  requestCreate,
  requestUpdate,
  requestDelete,
  requestExpire,
  
  // Offer events
  offerCreate,
  offerUpdate,
  offerAccept,
  offerReject,
  offerExpire,
  
  // Order events
  orderCreate,
  orderUpdate,
  orderStatusChange,
  orderComplete,
  orderCancel,
  
  // Chat events
  messageCreate,
  messageDelete,
  conversationCreate,
  
  // Shop events
  shopCreate,
  shopUpdate,
  shopVerify,
  
  // Admin events
  adminAction,
  dataExport,
  dataDelete,
  
  // System events
  systemError,
  securityAlert,
  rateLimitExceeded,
  validationFailed,
}

/// Audit event severity levels
enum AuditSeverity {
  info,     // Normal operations
  warning,  // Unusual but not critical
  error,    // Errors that need attention
  critical, // Security/critical issues
}

/// Audit Logging Service
/// 
/// Provides comprehensive audit logging for tracking user actions and system events.
/// This helps with:
/// - Security monitoring and incident investigation
/// - Compliance requirements (POPIA, GDPR)
/// - Debugging and troubleshooting
/// - Usage analytics and patterns
/// 
/// Usage:
/// ```dart
/// final auditLogger = ref.read(auditLoggerProvider);
/// 
/// await auditLogger.log(
///   eventType: AuditEventType.requestCreate,
///   description: 'User created a new part request',
///   metadata: {'requestId': '123', 'partCategory': 'Engine'},
/// );
/// ```
class AuditLoggingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // In-memory buffer for batch logging (reduces database writes)
  final List<AuditLogEntry> _buffer = [];
  static const int _maxBufferSize = 10;
  static const Duration _flushInterval = Duration(seconds: 30);
  
  DateTime? _lastFlush;
  
  /// Log an audit event
  Future<void> log({
    required AuditEventType eventType,
    required String description,
    AuditSeverity severity = AuditSeverity.info,
    Map<String, dynamic>? metadata,
    String? targetId,
    String? targetType,
  }) async {
    if (!EnvironmentConfig.enableAuditLogging) {
      return; // Audit logging disabled
    }
    
    final entry = AuditLogEntry(
      eventType: eventType,
      description: description,
      severity: severity,
      metadata: metadata ?? {},
      targetId: targetId,
      targetType: targetType,
      userId: _getCurrentUserId(),
      timestamp: DateTime.now(),
      ipAddress: null, // Would be captured server-side
      userAgent: null, // Would be captured server-side
    );
    
    // Add to buffer
    _buffer.add(entry);
    
    // Log critical events immediately
    if (severity == AuditSeverity.critical || severity == AuditSeverity.error) {
      await _flushBuffer();
    } else if (_buffer.length >= _maxBufferSize || _shouldFlush()) {
      await _flushBuffer();
    }
    
    // Also print to console in development
    if (EnvironmentConfig.isDevelopment) {
      _printLog(entry);
    }
  }
  
  /// Log authentication event
  Future<void> logAuth({
    required AuditEventType eventType,
    required String description,
    String? phone,
    bool success = true,
  }) async {
    await log(
      eventType: eventType,
      description: description,
      severity: success ? AuditSeverity.info : AuditSeverity.warning,
      metadata: {
        'phone': _maskPhone(phone),
        'success': success,
      },
    );
  }
  
  /// Log data modification event
  Future<void> logDataChange({
    required AuditEventType eventType,
    required String targetType,
    required String targetId,
    required String action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    await log(
      eventType: eventType,
      description: '$action $targetType',
      targetType: targetType,
      targetId: targetId,
      metadata: {
        'action': action,
        if (oldValues != null) 'oldValues': _sanitizeForLog(oldValues),
        if (newValues != null) 'newValues': _sanitizeForLog(newValues),
      },
    );
  }
  
  /// Log security event
  Future<void> logSecurity({
    required String description,
    required AuditSeverity severity,
    Map<String, dynamic>? metadata,
  }) async {
    await log(
      eventType: AuditEventType.securityAlert,
      description: description,
      severity: severity,
      metadata: metadata,
    );
  }
  
  /// Log rate limit exceeded
  Future<void> logRateLimitExceeded({
    required String endpoint,
    int? requestCount,
  }) async {
    await log(
      eventType: AuditEventType.rateLimitExceeded,
      description: 'Rate limit exceeded for endpoint: $endpoint',
      severity: AuditSeverity.warning,
      metadata: {
        'endpoint': endpoint,
        'requestCount': requestCount,
      },
    );
  }
  
  /// Log validation failure
  Future<void> logValidationFailed({
    required String operation,
    required Map<String, String> errors,
  }) async {
    await log(
      eventType: AuditEventType.validationFailed,
      description: 'Validation failed for: $operation',
      severity: AuditSeverity.info,
      metadata: {
        'operation': operation,
        'errors': errors,
      },
    );
  }
  
  /// Flush buffer to database
  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    
    final entries = List<AuditLogEntry>.from(_buffer);
    _buffer.clear();
    _lastFlush = DateTime.now();
    
    try {
      // Insert audit logs into Supabase
      await _supabase.from('audit_logs').insert(
        entries.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      // If database write fails, print to console at minimum
      if (EnvironmentConfig.isDevelopment) {
        print('Failed to write audit logs to database: $e');
        for (final entry in entries) {
          _printLog(entry);
        }
      }
      // Re-add failed entries to buffer (up to limit)
      if (_buffer.length + entries.length <= _maxBufferSize * 2) {
        _buffer.addAll(entries);
      }
    }
  }
  
  /// Check if buffer should be flushed based on time
  bool _shouldFlush() {
    if (_lastFlush == null) return true;
    return DateTime.now().difference(_lastFlush!) > _flushInterval;
  }
  
  /// Get current user ID if authenticated
  String? _getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }
  
  /// Mask phone number for privacy
  String? _maskPhone(String? phone) {
    if (phone == null || phone.length < 6) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 3)}';
  }
  
  /// Remove sensitive data from metadata before logging
  Map<String, dynamic> _sanitizeForLog(Map<String, dynamic> data) {
    final sensitiveFields = ['password', 'token', 'access_token', 'refresh_token', 'otp', 'pin'];
    final sanitized = Map<String, dynamic>.from(data);
    
    for (final field in sensitiveFields) {
      if (sanitized.containsKey(field)) {
        sanitized[field] = '[REDACTED]';
      }
    }
    
    return sanitized;
  }
  
  /// Print log to console (development only)
  void _printLog(AuditLogEntry entry) {
    final severityIcon = switch (entry.severity) {
      AuditSeverity.info => 'ℹ️',
      AuditSeverity.warning => '⚠️',
      AuditSeverity.error => '❌',
      AuditSeverity.critical => '🚨',
    };
    
    print('$severityIcon [AUDIT] ${entry.eventType.name}: ${entry.description}');
    if (entry.metadata.isNotEmpty) {
      print('   Metadata: ${entry.metadata}');
    }
  }
  
  /// Force flush any remaining logs (call on app close)
  Future<void> dispose() async {
    await _flushBuffer();
  }
  
  /// Get recent audit logs for current user (for debugging)
  Future<List<Map<String, dynamic>>> getRecentLogs({int limit = 50}) async {
    final userId = _getCurrentUserId();
    if (userId == null) return [];
    
    try {
      final response = await _supabase
          .from('audit_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}

/// Audit log entry model
class AuditLogEntry {
  final AuditEventType eventType;
  final String description;
  final AuditSeverity severity;
  final Map<String, dynamic> metadata;
  final String? targetId;
  final String? targetType;
  final String? userId;
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;
  
  AuditLogEntry({
    required this.eventType,
    required this.description,
    required this.severity,
    required this.metadata,
    this.targetId,
    this.targetType,
    this.userId,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
  });
  
  Map<String, dynamic> toJson() => {
    'event_type': eventType.name,
    'description': description,
    'severity': severity.name,
    'metadata': metadata,
    'target_id': targetId,
    'target_type': targetType,
    'user_id': userId,
    'created_at': timestamp.toIso8601String(),
    'ip_address': ipAddress,
    'user_agent': userAgent,
  };
}
