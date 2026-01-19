import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/environment_config.dart';

/// Request Validator Service Provider
final requestValidatorProvider = Provider<RequestValidatorService>((ref) {
  return RequestValidatorService();
});

/// Validation exception with field-specific errors
class ValidationException implements Exception {
  final Map<String, String> errors;
  
  ValidationException(this.errors);
  
  @override
  String toString() => 'ValidationException: ${errors.values.join(', ')}';
  
  String? getError(String field) => errors[field];
  
  bool get hasErrors => errors.isNotEmpty;
}

/// Request Validator Service
/// 
/// Provides comprehensive input validation for all API requests.
/// This helps prevent:
/// - SQL injection attacks
/// - XSS attacks via malicious input
/// - Invalid data corrupting the database
/// - Business logic violations
/// 
/// Usage:
/// ```dart
/// final validator = ref.read(requestValidatorProvider);
/// 
/// final result = validator.validatePartRequest(
///   vehicleMake: 'Toyota',
///   vehicleModel: 'Corolla',
///   vehicleYear: 2020,
///   partCategory: 'Engine',
/// );
/// 
/// if (!result.isValid) {
///   // Show errors to user
///   print(result.errors);
/// }
/// ```
class RequestValidatorService {
  
  // ===========================================
  // COMMON VALIDATION PATTERNS
  // ===========================================
  
  /// Valid phone number pattern (South African format)
  static final RegExp _phonePattern = RegExp(r'^(\+27|0)[6-8][0-9]{8}$');
  
  /// Valid email pattern
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  /// Valid name pattern (letters, spaces, hyphens, apostrophes)
  static final RegExp _namePattern = RegExp(r"^[a-zA-Z\s\-']{2,100}$");
  
  /// Valid VIN pattern (17 alphanumeric characters, excluding I, O, Q)
  static final RegExp _vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');
  
  /// Dangerous characters that could indicate injection attempts
  static final RegExp _dangerousChars = RegExp(r'[<>"\x27;\\]|--|\*/|/\*');
  
  /// Valid UUID pattern
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  
  // ===========================================
  // VALIDATION METHODS
  // ===========================================
  
  /// Validate user registration data
  ValidationResult validateRegistration({
    required String phone,
    String? email,
    required String fullName,
    required String role,
  }) {
    final errors = <String, String>{};
    
    // Phone validation
    if (phone.isEmpty) {
      errors['phone'] = 'Phone number is required';
    } else if (!_phonePattern.hasMatch(phone.replaceAll(' ', ''))) {
      errors['phone'] = 'Invalid phone number format. Use 0XX XXX XXXX or +27XX XXX XXXX';
    }
    
    // Email validation (optional but must be valid if provided)
    if (email != null && email.isNotEmpty) {
      if (!_emailPattern.hasMatch(email)) {
        errors['email'] = 'Invalid email address format';
      }
      if (email.length > 254) {
        errors['email'] = 'Email address is too long';
      }
    }
    
    // Name validation
    if (fullName.isEmpty) {
      errors['fullName'] = 'Full name is required';
    } else if (fullName.length < 2) {
      errors['fullName'] = 'Name must be at least 2 characters';
    } else if (fullName.length > 100) {
      errors['fullName'] = 'Name must be less than 100 characters';
    } else if (!_namePattern.hasMatch(fullName)) {
      errors['fullName'] = 'Name contains invalid characters';
    }
    
    // Role validation
    final validRoles = ['mechanic', 'shop_owner'];
    if (!validRoles.contains(role)) {
      errors['role'] = 'Invalid role. Must be mechanic or shop_owner';
    }
    
    // Check for injection attempts
    _checkForInjection(errors, 'fullName', fullName);
    if (email != null) _checkForInjection(errors, 'email', email);
    
    return ValidationResult(errors);
  }
  
  /// Validate part request data
  ValidationResult validatePartRequest({
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String partCategory,
    String? description,
    String? vin,
    String? engineNumber,
  }) {
    final errors = <String, String>{};
    
    // Vehicle make validation
    if (vehicleMake.isEmpty) {
      errors['vehicleMake'] = 'Vehicle make is required';
    } else if (vehicleMake.length > 50) {
      errors['vehicleMake'] = 'Vehicle make must be less than 50 characters';
    }
    
    // Vehicle model validation
    if (vehicleModel.isEmpty) {
      errors['vehicleModel'] = 'Vehicle model is required';
    } else if (vehicleModel.length > 50) {
      errors['vehicleModel'] = 'Vehicle model must be less than 50 characters';
    }
    
    // Vehicle year validation
    final currentYear = DateTime.now().year;
    if (vehicleYear < 1900 || vehicleYear > currentYear + 1) {
      errors['vehicleYear'] = 'Vehicle year must be between 1900 and ${currentYear + 1}';
    }
    
    // Part category validation
    final validCategories = [
      'Engine', 'Transmission', 'Suspension', 'Brakes', 'Electrical',
      'Body Parts', 'Interior', 'Exhaust', 'Cooling', 'Fuel System',
      'Steering', 'Wheels & Tyres', 'Lights', 'Other',
    ];
    if (partCategory.isEmpty) {
      errors['partCategory'] = 'Part category is required';
    } else if (!validCategories.contains(partCategory)) {
      errors['partCategory'] = 'Invalid part category';
    }
    
    // Description validation (optional)
    if (description != null && description.length > 1000) {
      errors['description'] = 'Description must be less than 1000 characters';
    }
    
    // VIN validation (optional but must be valid if provided)
    if (vin != null && vin.isNotEmpty) {
      if (!_vinPattern.hasMatch(vin.toUpperCase())) {
        errors['vin'] = 'Invalid VIN format. Must be 17 characters (excluding I, O, Q)';
      }
    }
    
    // Engine number validation (optional)
    if (engineNumber != null && engineNumber.length > 30) {
      errors['engineNumber'] = 'Engine number must be less than 30 characters';
    }
    
    // Check for injection attempts
    _checkForInjection(errors, 'vehicleMake', vehicleMake);
    _checkForInjection(errors, 'vehicleModel', vehicleModel);
    if (description != null) _checkForInjection(errors, 'description', description);
    
    return ValidationResult(errors);
  }
  
  /// Validate offer data
  ValidationResult validateOffer({
    required String requestId,
    required int priceCents,
    required int deliveryFeeCents,
    required int etaMinutes,
    required String stockStatus,
    String? message,
  }) {
    final errors = <String, String>{};
    
    // Request ID validation
    if (!_uuidPattern.hasMatch(requestId)) {
      errors['requestId'] = 'Invalid request ID format';
    }
    
    // Price validation
    if (priceCents < 0) {
      errors['priceCents'] = 'Price cannot be negative';
    } else if (priceCents > 10000000) { // Max R100,000
      errors['priceCents'] = 'Price exceeds maximum allowed (R100,000)';
    }
    
    // Delivery fee validation
    if (deliveryFeeCents < 0) {
      errors['deliveryFeeCents'] = 'Delivery fee cannot be negative';
    } else if (deliveryFeeCents > 500000) { // Max R5,000
      errors['deliveryFeeCents'] = 'Delivery fee exceeds maximum allowed (R5,000)';
    }
    
    // ETA validation
    if (etaMinutes < 0) {
      errors['etaMinutes'] = 'ETA cannot be negative';
    } else if (etaMinutes > 43200) { // Max 30 days
      errors['etaMinutes'] = 'ETA cannot exceed 30 days';
    }
    
    // Stock status validation
    final validStatuses = ['in_stock', 'can_order', 'out_of_stock'];
    if (!validStatuses.contains(stockStatus)) {
      errors['stockStatus'] = 'Invalid stock status';
    }
    
    // Message validation (optional)
    if (message != null && message.length > 500) {
      errors['message'] = 'Message must be less than 500 characters';
    }
    
    if (message != null) _checkForInjection(errors, 'message', message);
    
    return ValidationResult(errors);
  }
  
  /// Validate chat message
  ValidationResult validateMessage({
    required String conversationId,
    required String text,
  }) {
    final errors = <String, String>{};
    
    // Conversation ID validation
    if (!_uuidPattern.hasMatch(conversationId)) {
      errors['conversationId'] = 'Invalid conversation ID format';
    }
    
    // Text validation
    if (text.isEmpty) {
      errors['text'] = 'Message cannot be empty';
    } else if (text.length > 2000) {
      errors['text'] = 'Message must be less than 2000 characters';
    }
    
    return ValidationResult(errors);
  }
  
  /// Validate profile update data
  ValidationResult validateProfileUpdate({
    String? fullName,
    String? phone,
    String? streetAddress,
    String? suburb,
    String? city,
    String? postalCode,
    String? province,
  }) {
    final errors = <String, String>{};
    
    if (fullName != null) {
      if (fullName.length < 2) {
        errors['fullName'] = 'Name must be at least 2 characters';
      } else if (fullName.length > 100) {
        errors['fullName'] = 'Name must be less than 100 characters';
      }
      _checkForInjection(errors, 'fullName', fullName);
    }
    
    if (phone != null && phone.isNotEmpty) {
      if (!_phonePattern.hasMatch(phone.replaceAll(' ', ''))) {
        errors['phone'] = 'Invalid phone number format';
      }
    }
    
    if (streetAddress != null && streetAddress.length > 200) {
      errors['streetAddress'] = 'Street address must be less than 200 characters';
    }
    
    if (suburb != null && suburb.length > 100) {
      errors['suburb'] = 'Suburb must be less than 100 characters';
    }
    
    if (city != null && city.length > 100) {
      errors['city'] = 'City must be less than 100 characters';
    }
    
    if (postalCode != null && postalCode.isNotEmpty) {
      if (!RegExp(r'^\d{4}$').hasMatch(postalCode)) {
        errors['postalCode'] = 'Invalid postal code format (must be 4 digits)';
      }
    }
    
    if (province != null && province.length > 50) {
      errors['province'] = 'Province must be less than 50 characters';
    }
    
    return ValidationResult(errors);
  }
  
  /// Validate UUID format
  bool isValidUuid(String? value) {
    if (value == null) return false;
    return _uuidPattern.hasMatch(value);
  }
  
  /// Validate phone number format
  bool isValidPhone(String? value) {
    if (value == null) return false;
    return _phonePattern.hasMatch(value.replaceAll(' ', ''));
  }
  
  /// Validate email format
  bool isValidEmail(String? value) {
    if (value == null) return false;
    return _emailPattern.hasMatch(value);
  }
  
  /// Sanitize text input (remove potential dangerous characters)
  String sanitizeText(String input) {
    return input
        .replaceAll(_dangerousChars, '')
        .trim();
  }
  
  /// Check for potential injection attacks
  void _checkForInjection(Map<String, String> errors, String field, String value) {
    if (!EnvironmentConfig.enableRequestValidation) return;
    
    if (_dangerousChars.hasMatch(value)) {
      errors[field] = '$field contains invalid characters';
    }
  }
}

/// Result of validation
class ValidationResult {
  final Map<String, String> errors;
  
  ValidationResult(this.errors);
  
  bool get isValid => errors.isEmpty;
  
  String? getError(String field) => errors[field];
  
  String get firstError => errors.values.first;
  
  List<String> get allErrors => errors.values.toList();
  
  @override
  String toString() => isValid ? 'Valid' : 'Invalid: ${errors.values.join(', ')}';
}
