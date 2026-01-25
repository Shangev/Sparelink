import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/environment_config.dart';
import 'audit_logging_service.dart';

/// Data Retention Service Provider
final dataRetentionProvider = Provider<DataRetentionService>((ref) {
  final auditLogger = ref.read(auditLoggerProvider);
  return DataRetentionService(auditLogger);
});

/// Data Retention Policy Configuration
/// 
/// Defines how long different types of data are retained before cleanup.
/// These policies help with:
/// - POPIA/GDPR compliance
/// - Storage cost management
/// - Database performance
/// - User privacy
class DataRetentionPolicy {
  /// Retention period for audit logs (days)
  /// Critical/error logs are retained longer
  static const int auditLogsRetentionDays = 90;
  static const int criticalAuditLogsRetentionDays = 365;
  
  /// Retention period for expired part requests (days)
  /// Requests that were never fulfilled
  static const int expiredRequestsRetentionDays = 180;
  
  /// Retention period for completed orders (days)
  /// After this, order details are archived
  static const int completedOrdersRetentionDays = 730; // 2 years (legal requirement)
  
  /// Retention period for cancelled orders (days)
  static const int cancelledOrdersRetentionDays = 90;
  
  /// Retention period for rejected/expired offers (days)
  static const int rejectedOffersRetentionDays = 30;
  
  /// Retention period for old chat messages (days)
  /// Messages in inactive conversations
  static const int inactiveChatRetentionDays = 365;
  
  /// Retention period for deleted user data (days)
  /// Soft-deleted data before permanent removal
  static const int deletedDataRetentionDays = 30;
  
  /// Retention period for uploaded images of completed/cancelled requests (days)
  static const int imageRetentionDays = 180;
  
  /// Retention period for notification history (days)
  static const int notificationRetentionDays = 30;
  
  /// Retention period for user sessions (days)
  static const int sessionRetentionDays = 30;
}

/// Data Retention Service
/// 
/// Manages data cleanup and retention policies for the SpareLink database.
/// This service should be run periodically (e.g., daily via cron job) to:
/// - Clean up old/expired data
/// - Archive completed transactions
/// - Maintain database performance
/// - Ensure compliance with data protection regulations
/// 
/// Usage:
/// ```dart
/// final retentionService = ref.read(dataRetentionProvider);
/// 
/// // Run full cleanup (typically called by scheduled job)
/// final results = await retentionService.runFullCleanup();
/// print('Cleaned up ${results.totalRecordsDeleted} records');
/// ```
class DataRetentionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuditLoggingService _auditLogger;
  
  DataRetentionService(this._auditLogger);
  
  /// Run full data cleanup based on retention policies
  Future<CleanupResult> runFullCleanup() async {
    final results = CleanupResult();
    
    try {
      // Clean up each data type
      results.auditLogsDeleted = await _cleanupAuditLogs();
      results.expiredRequestsDeleted = await _cleanupExpiredRequests();
      results.rejectedOffersDeleted = await _cleanupRejectedOffers();
      results.oldNotificationsDeleted = await _cleanupOldNotifications();
      results.expiredSessionsDeleted = await _cleanupExpiredSessions();
      
      // Log the cleanup
      await _auditLogger.log(
        eventType: AuditEventType.adminAction,
        description: 'Data retention cleanup completed',
        metadata: results.toJson(),
      );
      
      if (EnvironmentConfig.isDevelopment) {
        print('=== Data Retention Cleanup Complete ===');
        print('Audit logs deleted: ${results.auditLogsDeleted}');
        print('Expired requests deleted: ${results.expiredRequestsDeleted}');
        print('Rejected offers deleted: ${results.rejectedOffersDeleted}');
        print('Old notifications deleted: ${results.oldNotificationsDeleted}');
        print('Expired sessions deleted: ${results.expiredSessionsDeleted}');
        print('Total: ${results.totalRecordsDeleted}');
      }
      
    } catch (e) {
      await _auditLogger.log(
        eventType: AuditEventType.systemError,
        description: 'Data retention cleanup failed',
        severity: AuditSeverity.error,
        metadata: {'error': e.toString()},
      );
      rethrow;
    }
    
    return results;
  }
  
  /// Clean up old audit logs
  Future<int> _cleanupAuditLogs() async {
    try {
      // This calls the database function we created
      final response = await _supabase.rpc(
        'cleanup_old_audit_logs',
        params: {'retention_days': DataRetentionPolicy.auditLogsRetentionDays},
      );
      return response as int? ?? 0;
    } catch (e) {
      // Function might not exist yet
      if (EnvironmentConfig.isDevelopment) {
        print('Audit log cleanup skipped: $e');
      }
      return 0;
    }
  }
  
  /// Clean up expired part requests
  Future<int> _cleanupExpiredRequests() async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: DataRetentionPolicy.expiredRequestsRetentionDays),
      );
      
      // First, get IDs of requests to delete (for associated data cleanup)
      final expiredRequests = await _supabase
          .from('part_requests')
          .select('id')
          .eq('status', 'expired')
          .lt('created_at', cutoffDate.toIso8601String());
      
      if (expiredRequests.isEmpty) return 0;
      
      // SAFETY: Ensure we only have valid string IDs
      final requestIds = (expiredRequests as List)
          .map((r) => r['id'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      
      if (requestIds.isEmpty) return 0;
      
      // Delete associated offers first
      await _supabase
          .from('offers')
          .delete()
          .inFilter('request_id', requestIds);
      
      // Delete the requests
      await _supabase
          .from('part_requests')
          .delete()
          .inFilter('id', requestIds);
      
      return requestIds.length;
    } catch (e) {
      if (EnvironmentConfig.isDevelopment) {
        print('Expired requests cleanup error: $e');
      }
      return 0;
    }
  }
  
  /// Clean up rejected/expired offers
  Future<int> _cleanupRejectedOffers() async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: DataRetentionPolicy.rejectedOffersRetentionDays),
      );
      
      final response = await _supabase
          .from('offers')
          .delete()
          .inFilter('status', ['rejected', 'expired'])
          .lt('created_at', cutoffDate.toIso8601String())
          .select('id');
      
      return (response as List).length;
    } catch (e) {
      if (EnvironmentConfig.isDevelopment) {
        print('Rejected offers cleanup error: $e');
      }
      return 0;
    }
  }
  
  /// Clean up old notifications
  Future<int> _cleanupOldNotifications() async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: DataRetentionPolicy.notificationRetentionDays),
      );
      
      final response = await _supabase
          .from('notifications')
          .delete()
          .eq('read', true) // Only delete read notifications
          .lt('created_at', cutoffDate.toIso8601String())
          .select('id');
      
      return (response as List).length;
    } catch (e) {
      if (EnvironmentConfig.isDevelopment) {
        print('Notifications cleanup error: $e');
      }
      return 0;
    }
  }
  
  /// Clean up expired sessions
  Future<int> _cleanupExpiredSessions() async {
    // Sessions are typically managed by Supabase Auth
    // This is a placeholder for custom session tracking if implemented
    return 0;
  }
  
  /// Archive old completed orders (move to archive table)
  Future<int> archiveOldOrders() async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: DataRetentionPolicy.completedOrdersRetentionDays),
      );
      
      // Get old completed orders
      final oldOrders = await _supabase
          .from('orders')
          .select()
          .eq('status', 'completed')
          .lt('completed_at', cutoffDate.toIso8601String());
      
      if ((oldOrders as List).isEmpty) return 0;
      
      // Insert into archive table (create this table first)
      // await _supabase.from('orders_archive').insert(oldOrders);
      
      // For now, just return count - actual archiving requires archive table
      return oldOrders.length;
    } catch (e) {
      if (EnvironmentConfig.isDevelopment) {
        print('Order archiving error: $e');
      }
      return 0;
    }
  }
  
  /// Get retention policy summary
  Map<String, int> getRetentionPolicySummary() {
    return {
      'auditLogs': DataRetentionPolicy.auditLogsRetentionDays,
      'criticalAuditLogs': DataRetentionPolicy.criticalAuditLogsRetentionDays,
      'expiredRequests': DataRetentionPolicy.expiredRequestsRetentionDays,
      'completedOrders': DataRetentionPolicy.completedOrdersRetentionDays,
      'cancelledOrders': DataRetentionPolicy.cancelledOrdersRetentionDays,
      'rejectedOffers': DataRetentionPolicy.rejectedOffersRetentionDays,
      'inactiveChats': DataRetentionPolicy.inactiveChatRetentionDays,
      'deletedData': DataRetentionPolicy.deletedDataRetentionDays,
      'images': DataRetentionPolicy.imageRetentionDays,
      'notifications': DataRetentionPolicy.notificationRetentionDays,
      'sessions': DataRetentionPolicy.sessionRetentionDays,
    };
  }
  
  /// Handle user data deletion request (POPIA/GDPR right to erasure)
  Future<void> deleteUserData(String userId) async {
    await _auditLogger.log(
      eventType: AuditEventType.dataDelete,
      description: 'User data deletion requested',
      severity: AuditSeverity.warning,
      metadata: {'userId': userId},
    );
    
    // Soft delete user data first (30 day retention before permanent deletion)
    // This allows for accidental deletion recovery
    
    try {
      // Mark profile as deleted
      await _supabase
          .from('profiles')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'full_name': '[DELETED]',
            'phone': null,
            'email': null,
          })
          .eq('id', userId);
      
      // Anonymize chat messages (keep structure, remove content)
      await _supabase
          .from('messages')
          .update({'content': '[Message deleted]'})
          .eq('sender_id', userId);
      
      // Mark requests as deleted
      await _supabase
          .from('part_requests')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId);
      
      await _auditLogger.log(
        eventType: AuditEventType.dataDelete,
        description: 'User data soft-deleted successfully',
        metadata: {'userId': userId},
      );
      
    } catch (e) {
      await _auditLogger.log(
        eventType: AuditEventType.systemError,
        description: 'User data deletion failed',
        severity: AuditSeverity.error,
        metadata: {'userId': userId, 'error': e.toString()},
      );
      rethrow;
    }
  }
  
  /// Export user data (POPIA/GDPR right to portability)
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    await _auditLogger.log(
      eventType: AuditEventType.dataExport,
      description: 'User data export requested',
      metadata: {'userId': userId},
    );
    
    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      final requests = await _supabase
          .from('part_requests')
          .select()
          .eq('user_id', userId);
      
      final orders = await _supabase
          .from('orders')
          .select()
          .eq('buyer_id', userId);
      
      // Compile all user data
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'profile': profile,
        'partRequests': requests,
        'orders': orders,
      };
      
      await _auditLogger.log(
        eventType: AuditEventType.dataExport,
        description: 'User data exported successfully',
        metadata: {'userId': userId},
      );
      
      return exportData;
      
    } catch (e) {
      await _auditLogger.log(
        eventType: AuditEventType.systemError,
        description: 'User data export failed',
        severity: AuditSeverity.error,
        metadata: {'userId': userId, 'error': e.toString()},
      );
      rethrow;
    }
  }
}

/// Result of cleanup operation
class CleanupResult {
  int auditLogsDeleted = 0;
  int expiredRequestsDeleted = 0;
  int rejectedOffersDeleted = 0;
  int oldNotificationsDeleted = 0;
  int expiredSessionsDeleted = 0;
  int archivedOrders = 0;
  
  int get totalRecordsDeleted =>
      auditLogsDeleted +
      expiredRequestsDeleted +
      rejectedOffersDeleted +
      oldNotificationsDeleted +
      expiredSessionsDeleted;
  
  Map<String, dynamic> toJson() => {
    'auditLogsDeleted': auditLogsDeleted,
    'expiredRequestsDeleted': expiredRequestsDeleted,
    'rejectedOffersDeleted': rejectedOffersDeleted,
    'oldNotificationsDeleted': oldNotificationsDeleted,
    'expiredSessionsDeleted': expiredSessionsDeleted,
    'archivedOrders': archivedOrders,
    'totalRecordsDeleted': totalRecordsDeleted,
  };
}
