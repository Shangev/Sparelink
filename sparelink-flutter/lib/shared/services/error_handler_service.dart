import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// ERROR HANDLER SERVICE
// Pass 2 Phase 4 Implementation
// Provides standardized error handling across the app
// =============================================================================

/// Custom app exception with user-friendly messages
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final bool isRecoverable;
  final ErrorType type;
  
  AppException({
    required this.message,
    this.code,
    this.originalError,
    this.isRecoverable = true,
    this.type = ErrorType.unknown,
  });
  
  @override
  String toString() => message;
  
  /// Check if this error should be shown to the user
  bool get shouldShowToUser => type != ErrorType.silent;
  
  /// Get a user-friendly action suggestion
  String get actionSuggestion {
    switch (type) {
      case ErrorType.network:
        return 'Please check your internet connection and try again.';
      case ErrorType.auth:
        return 'Please log in again.';
      case ErrorType.validation:
        return 'Please check your input and try again.';
      case ErrorType.notFound:
        return 'The requested item could not be found.';
      case ErrorType.permission:
        return 'You don\'t have permission for this action.';
      case ErrorType.conflict:
        return 'This action conflicts with existing data.';
      case ErrorType.server:
        return 'Server error. Please try again later.';
      case ErrorType.silent:
      case ErrorType.unknown:
        return 'Please try again or contact support.';
    }
  }
}

/// Error categories for different handling strategies
enum ErrorType {
  network,     // Network/connection issues
  auth,        // Authentication errors
  validation,  // Input validation errors
  notFound,    // Resource not found
  permission,  // Permission denied
  conflict,    // Data conflict (e.g., duplicate)
  server,      // Server/database errors
  silent,      // Should not show to user
  unknown,     // Unclassified errors
}

/// Centralized error handler for the app
class ErrorHandler {
  // Singleton pattern
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();
  
  /// Wrap any async operation with standardized error handling
  /// 
  /// Example:
  /// ```dart
  /// final result = await ErrorHandler.guard(
  ///   operation: () => supabaseService.getMechanicRequests(userId),
  ///   operationName: 'getMechanicRequests',
  /// );
  /// ```
  static Future<T> guard<T>({
    required Future<T> Function() operation,
    required String operationName,
    T? fallbackValue,
    bool silent = false,
  }) async {
    try {
      return await operation();
    } on PostgrestException catch (e) {
      debugPrint('⚠️ [$operationName] PostgrestException: ${e.code} - ${e.message}');
      throw _mapPostgrestException(e);
    } on AuthException catch (e) {
      debugPrint('⚠️ [$operationName] AuthException: ${e.message}');
      throw _mapAuthException(e);
    } on StorageException catch (e) {
      debugPrint('⚠️ [$operationName] StorageException: ${e.message}');
      throw _mapStorageException(e);
    } on AppException {
      rethrow; // Already mapped
    } catch (e) {
      debugPrint('⚠️ [$operationName] Unexpected error: $e');
      
      // Return fallback if provided
      if (fallbackValue != null) {
        debugPrint('⚠️ [$operationName] Returning fallback value');
        return fallbackValue;
      }
      
      // Check for network errors
      if (_isNetworkError(e)) {
        throw AppException(
          message: 'Network error. Please check your connection.',
          originalError: e,
          type: ErrorType.network,
        );
      }
      
      throw AppException(
        message: 'Something went wrong. Please try again.',
        originalError: e,
        type: silent ? ErrorType.silent : ErrorType.unknown,
      );
    }
  }
  
  /// Map PostgrestException to AppException with user-friendly messages
  static AppException _mapPostgrestException(PostgrestException e) {
    final code = e.code;
    final message = e.message ?? '';
    
    // Custom application error codes (from our triggers)
    if (code == 'P0001' || message.contains('QUOTE_ALREADY_ACCEPTED')) {
      return AppException(
        message: 'This quote has already been accepted.',
        code: code,
        originalError: e,
        type: ErrorType.conflict,
        isRecoverable: false,
      );
    }
    
    if (code == 'P0002' || message.contains('QUOTE_EXPIRED')) {
      return AppException(
        message: 'This quote has expired. Please request a new quote.',
        code: code,
        originalError: e,
        type: ErrorType.validation,
        isRecoverable: false,
      );
    }
    
    if (code == 'P0003' || message.contains('QUOTE_REJECTED')) {
      return AppException(
        message: 'This quote has been rejected and cannot be accepted.',
        code: code,
        originalError: e,
        type: ErrorType.validation,
        isRecoverable: false,
      );
    }
    
    if (code == 'P0010' || message.contains('INVALID_STATUS_TRANSITION')) {
      return AppException(
        message: 'Invalid status change. Please refresh and try again.',
        code: code,
        originalError: e,
        type: ErrorType.validation,
      );
    }
    
    // Standard PostgreSQL error codes
    switch (code) {
      case 'PGRST116':
        return AppException(
          message: 'No data found.',
          code: code,
          originalError: e,
          type: ErrorType.notFound,
        );
      case '23505':
        return AppException(
          message: 'This item already exists.',
          code: code,
          originalError: e,
          type: ErrorType.conflict,
        );
      case '23503':
        return AppException(
          message: 'Cannot delete - this item is being used elsewhere.',
          code: code,
          originalError: e,
          type: ErrorType.conflict,
        );
      case '42501':
        return AppException(
          message: 'You don\'t have permission for this action.',
          code: code,
          originalError: e,
          type: ErrorType.permission,
          isRecoverable: false,
        );
      case '42P01':
        return AppException(
          message: 'Database configuration error. Please contact support.',
          code: code,
          originalError: e,
          type: ErrorType.server,
          isRecoverable: false,
        );
      default:
        return AppException(
          message: 'Database error. Please try again.',
          code: code,
          originalError: e,
          type: ErrorType.server,
        );
    }
  }
  
  /// Map AuthException to AppException
  static AppException _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return AppException(
        message: 'Invalid phone number or password.',
        originalError: e,
        type: ErrorType.auth,
      );
    }
    
    if (msg.contains('email not confirmed') || msg.contains('phone not confirmed')) {
      return AppException(
        message: 'Please verify your phone number first.',
        originalError: e,
        type: ErrorType.auth,
      );
    }
    
    if (msg.contains('expired') || msg.contains('session')) {
      return AppException(
        message: 'Your session has expired. Please log in again.',
        originalError: e,
        type: ErrorType.auth,
        isRecoverable: false,
      );
    }
    
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return AppException(
        message: 'Too many attempts. Please wait a moment and try again.',
        originalError: e,
        type: ErrorType.validation,
      );
    }
    
    if (msg.contains('user already registered')) {
      return AppException(
        message: 'This phone number is already registered.',
        originalError: e,
        type: ErrorType.conflict,
      );
    }
    
    return AppException(
      message: 'Authentication failed. Please try again.',
      originalError: e,
      type: ErrorType.auth,
    );
  }
  
  /// Map StorageException to AppException
  static AppException _mapStorageException(StorageException e) {
    final msg = e.message?.toLowerCase() ?? '';
    
    if (msg.contains('payload too large') || msg.contains('file size') || msg.contains('exceeds')) {
      return AppException(
        message: 'File is too large. Maximum size is 10MB.',
        originalError: e,
        type: ErrorType.validation,
      );
    }
    
    if (msg.contains('not found')) {
      return AppException(
        message: 'File not found.',
        originalError: e,
        type: ErrorType.notFound,
      );
    }
    
    if (msg.contains('permission') || msg.contains('unauthorized')) {
      return AppException(
        message: 'Permission denied to access this file.',
        originalError: e,
        type: ErrorType.permission,
      );
    }
    
    if (msg.contains('invalid') && msg.contains('type')) {
      return AppException(
        message: 'Invalid file type. Please use JPG, PNG, or WebP.',
        originalError: e,
        type: ErrorType.validation,
      );
    }
    
    return AppException(
      message: 'Failed to upload file. Please try again.',
      originalError: e,
      type: ErrorType.server,
    );
  }
  
  /// Check if an error is network-related
  static bool _isNetworkError(dynamic e) {
    final errorString = e.toString().toLowerCase();
    return errorString.contains('socketexception') ||
           errorString.contains('connection refused') ||
           errorString.contains('connection reset') ||
           errorString.contains('network is unreachable') ||
           errorString.contains('no internet') ||
           errorString.contains('failed host lookup') ||
           errorString.contains('timeout');
  }
  
  /// Log error for debugging (could be extended to send to error reporting service)
  static void logError(String operation, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('════════════════════════════════════════');
    debugPrint('❌ ERROR in $operation');
    debugPrint('Error: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace:\n$stackTrace');
    }
    debugPrint('════════════════════════════════════════');
    
    // TODO: Send to error reporting service (e.g., Sentry, Firebase Crashlytics)
    // ErrorReportingService.captureException(error, stackTrace);
  }
}
