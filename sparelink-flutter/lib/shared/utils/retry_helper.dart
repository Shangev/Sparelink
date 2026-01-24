import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// RETRY HELPER UTILITY
// Pass 2 Phase 4 Implementation
// Provides retry logic with exponential backoff
// =============================================================================

/// Configuration for retry behavior
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool addJitter;
  
  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.addJitter = true,
  });
  
  /// Default configuration for network requests
  static const network = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 30),
  );
  
  /// Configuration for critical operations (more retries)
  static const critical = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 60),
  );
  
  /// Configuration for fast retry (UI operations)
  static const fast = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 5),
  );
}

/// Result of a retry operation
class RetryResult<T> {
  final T? value;
  final bool success;
  final int attempts;
  final Duration totalDuration;
  final dynamic lastError;
  
  const RetryResult({
    this.value,
    required this.success,
    required this.attempts,
    required this.totalDuration,
    this.lastError,
  });
  
  /// Get value or throw last error
  T get valueOrThrow {
    if (success && value != null) {
      return value as T;
    }
    throw lastError ?? Exception('Operation failed after $attempts attempts');
  }
}

/// Helper class for retry operations with exponential backoff
class RetryHelper {
  static final Random _random = Random();
  
  /// Retry an operation with exponential backoff
  /// 
  /// Example:
  /// ```dart
  /// final result = await RetryHelper.withRetry(
  ///   operation: () => api.fetchData(),
  ///   operationName: 'fetchData',
  ///   shouldRetry: RetryHelper.isRetryable,
  /// );
  /// ```
  static Future<T> withRetry<T>({
    required Future<T> Function() operation,
    String? operationName,
    RetryConfig config = const RetryConfig(),
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, Duration delay, dynamic error)? onRetry,
  }) async {
    final stopwatch = Stopwatch()..start();
    int attempt = 0;
    Duration delay = config.initialDelay;
    dynamic lastError;
    
    while (true) {
      try {
        attempt++;
        final result = await operation();
        
        if (attempt > 1) {
          debugPrint('✅ [${operationName ?? 'Operation'}] Succeeded on attempt $attempt');
        }
        
        return result;
      } catch (e) {
        lastError = e;
        
        // Check if we should retry
        final canRetry = attempt < config.maxAttempts;
        final errorRetryable = shouldRetry?.call(e) ?? isRetryable(e);
        
        if (!canRetry || !errorRetryable) {
          debugPrint('❌ [${operationName ?? 'Operation'}] Failed after $attempt attempts: $e');
          rethrow;
        }
        
        // Calculate delay with jitter
        if (config.addJitter) {
          // Add random jitter of ±25%
          final jitterFactor = 0.75 + (_random.nextDouble() * 0.5);
          delay = Duration(
            milliseconds: (delay.inMilliseconds * jitterFactor).round(),
          );
        }
        
        // Cap at max delay
        if (delay > config.maxDelay) {
          delay = config.maxDelay;
        }
        
        debugPrint('⚠️ [${operationName ?? 'Operation'}] Attempt $attempt failed, '
            'retrying in ${delay.inMilliseconds}ms...');
        
        // Notify callback
        onRetry?.call(attempt, delay, e);
        
        // Wait before retry
        await Future.delayed(delay);
        
        // Increase delay for next attempt (exponential backoff)
        delay = Duration(
          milliseconds: (delay.inMilliseconds * config.backoffMultiplier).round(),
        );
      }
    }
  }
  
  /// Retry an operation and return detailed result
  static Future<RetryResult<T>> withRetryResult<T>({
    required Future<T> Function() operation,
    String? operationName,
    RetryConfig config = const RetryConfig(),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    final stopwatch = Stopwatch()..start();
    int attempt = 0;
    Duration delay = config.initialDelay;
    dynamic lastError;
    
    while (true) {
      try {
        attempt++;
        final result = await operation();
        stopwatch.stop();
        
        return RetryResult(
          value: result,
          success: true,
          attempts: attempt,
          totalDuration: stopwatch.elapsed,
        );
      } catch (e) {
        lastError = e;
        
        final canRetry = attempt < config.maxAttempts;
        final errorRetryable = shouldRetry?.call(e) ?? isRetryable(e);
        
        if (!canRetry || !errorRetryable) {
          stopwatch.stop();
          return RetryResult(
            success: false,
            attempts: attempt,
            totalDuration: stopwatch.elapsed,
            lastError: e,
          );
        }
        
        if (config.addJitter) {
          final jitterFactor = 0.75 + (_random.nextDouble() * 0.5);
          delay = Duration(
            milliseconds: (delay.inMilliseconds * jitterFactor).round(),
          );
        }
        
        if (delay > config.maxDelay) {
          delay = config.maxDelay;
        }
        
        await Future.delayed(delay);
        
        delay = Duration(
          milliseconds: (delay.inMilliseconds * config.backoffMultiplier).round(),
        );
      }
    }
  }
  
  /// Check if an error is retryable
  /// 
  /// Returns false for validation errors, conflicts, and permission issues
  /// Returns true for network errors, timeouts, and server errors
  static bool isRetryable(dynamic error) {
    // Don't retry PostgrestException validation errors
    if (error is PostgrestException) {
      final code = error.code;
      // Don't retry constraint violations or custom validation errors
      if (['23505', '23503', 'P0001', 'P0002', 'P0003', 'P0010', '42501'].contains(code)) {
        return false;
      }
      // Retry server errors
      return true;
    }
    
    // Don't retry auth errors (need user action)
    if (error is AuthException) {
      return false;
    }
    
    // Don't retry storage validation errors
    if (error is StorageException) {
      final msg = error.message?.toLowerCase() ?? '';
      if (msg.contains('payload too large') || 
          msg.contains('invalid') || 
          msg.contains('permission')) {
        return false;
      }
      return true;
    }
    
    // Check for network errors (should retry)
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('network')) {
      return true;
    }
    
    // Default: retry other errors
    return true;
  }
  
  /// Check if an error is a network error
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
           errorString.contains('connection refused') ||
           errorString.contains('connection reset') ||
           errorString.contains('network is unreachable') ||
           errorString.contains('no internet') ||
           errorString.contains('failed host lookup') ||
           errorString.contains('timeout');
  }
  
  /// Check if an error is a timeout error
  static bool isTimeoutError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('timeout') ||
           errorString.contains('timed out') ||
           errorString.contains('deadline exceeded');
  }
}

/// Extension to add retry capability to any Future
extension RetryFutureExtension<T> on Future<T> Function() {
  /// Retry this operation with default config
  Future<T> withRetry({
    RetryConfig config = const RetryConfig(),
    String? operationName,
  }) {
    return RetryHelper.withRetry(
      operation: this,
      config: config,
      operationName: operationName,
    );
  }
}
