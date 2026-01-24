/**
 * Pass 4: Payload Validation Utilities
 * 
 * Server-side validation to ensure backend rejects malformed data
 * even if someone bypasses the UI or sends direct API requests.
 * 
 * Security features:
 * - UUID format validation
 * - Price range validation
 * - Text length limits (XSS prevention)
 * - Enum validation
 * - Dangerous character detection
 */

// =====================================================
// VALIDATION PATTERNS
// =====================================================

const UUID_PATTERN = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const PHONE_PATTERN = /^(\+27|0)[6-8][0-9]{8}$/;
const EMAIL_PATTERN = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
const DANGEROUS_CHARS = /<script|javascript:|on\w+\s*=|<\s*iframe|<\s*object|<\s*embed/i;

// =====================================================
// VALIDATION RESULT TYPE
// =====================================================

export interface ValidationResult {
  isValid: boolean;
  errors: Record<string, string>;
}

// =====================================================
// PRIMITIVE VALIDATORS
// =====================================================

export function isValidUuid(value: unknown): boolean {
  if (typeof value !== 'string') return false;
  return UUID_PATTERN.test(value);
}

export function isValidPhone(value: unknown): boolean {
  if (typeof value !== 'string') return false;
  return PHONE_PATTERN.test(value.replace(/\s/g, ''));
}

export function isValidEmail(value: unknown): boolean {
  if (typeof value !== 'string') return false;
  return EMAIL_PATTERN.test(value) && value.length <= 254;
}

export function containsDangerousChars(value: unknown): boolean {
  if (typeof value !== 'string') return false;
  return DANGEROUS_CHARS.test(value);
}

export function sanitizeText(value: string): string {
  return value
    .replace(/<[^>]*>/g, '') // Remove HTML tags
    .replace(/javascript:/gi, '')
    .trim();
}

// =====================================================
// PRICE VALIDATION
// =====================================================

export function validatePrice(
  value: unknown,
  fieldName: string,
  maxCents: number = 100000000 // R1,000,000 default max
): string | null {
  if (value === undefined || value === null) return null; // Optional field
  
  const num = Number(value);
  
  if (isNaN(num)) {
    return `${fieldName} must be a number`;
  }
  
  if (num < 0) {
    return `${fieldName} cannot be negative`;
  }
  
  if (num > maxCents) {
    return `${fieldName} exceeds maximum allowed value`;
  }
  
  if (!Number.isInteger(num)) {
    return `${fieldName} must be a whole number (cents)`;
  }
  
  return null;
}

// =====================================================
// TEXT VALIDATION
// =====================================================

export function validateText(
  value: unknown,
  fieldName: string,
  options: {
    required?: boolean;
    minLength?: number;
    maxLength?: number;
    allowEmpty?: boolean;
  } = {}
): string | null {
  const { required = false, minLength = 0, maxLength = 1000, allowEmpty = true } = options;
  
  if (value === undefined || value === null) {
    return required ? `${fieldName} is required` : null;
  }
  
  if (typeof value !== 'string') {
    return `${fieldName} must be a string`;
  }
  
  const trimmed = value.trim();
  
  if (!allowEmpty && trimmed.length === 0) {
    return `${fieldName} cannot be empty`;
  }
  
  if (required && trimmed.length === 0) {
    return `${fieldName} is required`;
  }
  
  if (trimmed.length < minLength) {
    return `${fieldName} must be at least ${minLength} characters`;
  }
  
  if (trimmed.length > maxLength) {
    return `${fieldName} must be less than ${maxLength} characters`;
  }
  
  if (containsDangerousChars(trimmed)) {
    return `${fieldName} contains potentially dangerous content`;
  }
  
  return null;
}

// =====================================================
// ENUM VALIDATION
// =====================================================

export function validateEnum<T extends string>(
  value: unknown,
  fieldName: string,
  validValues: readonly T[],
  required: boolean = true
): string | null {
  if (value === undefined || value === null) {
    return required ? `${fieldName} is required` : null;
  }
  
  if (typeof value !== 'string') {
    return `${fieldName} must be a string`;
  }
  
  if (!validValues.includes(value as T)) {
    return `${fieldName} must be one of: ${validValues.join(', ')}`;
  }
  
  return null;
}

// =====================================================
// INVENTORY VALIDATION
// =====================================================

const VALID_CONDITIONS = ['new', 'used', 'refurbished'] as const;
const VALID_CATEGORIES = [
  'Engine', 'Transmission', 'Suspension', 'Brakes', 'Electrical',
  'Body Parts', 'Interior', 'Exhaust', 'Cooling', 'Fuel System',
  'Steering', 'Wheels & Tyres', 'Lights', 'Filters', 'Other'
] as const;

export function validateInventoryItem(data: Record<string, unknown>): ValidationResult {
  const errors: Record<string, string> = {};
  
  // Required fields
  if (!isValidUuid(data.shop_id)) {
    errors.shop_id = 'Invalid shop ID format';
  }
  
  const partNameError = validateText(data.part_name, 'Part name', { required: true, maxLength: 200 });
  if (partNameError) errors.part_name = partNameError;
  
  const categoryError = validateEnum(data.category, 'Category', VALID_CATEGORIES);
  if (categoryError) errors.category = categoryError;
  
  // Optional fields with validation
  const descError = validateText(data.description, 'Description', { maxLength: 2000 });
  if (descError) errors.description = descError;
  
  const partNumError = validateText(data.part_number, 'Part number', { maxLength: 100 });
  if (partNumError) errors.part_number = partNumError;
  
  const costError = validatePrice(data.cost_price, 'Cost price', 100000000);
  if (costError) errors.cost_price = costError;
  
  const sellingError = validatePrice(data.selling_price, 'Selling price', 100000000);
  if (sellingError) errors.selling_price = sellingError;
  
  // Stock quantity validation
  if (data.stock_quantity !== undefined) {
    const qty = Number(data.stock_quantity);
    if (isNaN(qty) || qty < 0 || !Number.isInteger(qty)) {
      errors.stock_quantity = 'Stock quantity must be a non-negative whole number';
    }
    if (qty > 1000000) {
      errors.stock_quantity = 'Stock quantity exceeds maximum allowed';
    }
  }
  
  // Condition validation
  if (data.condition !== undefined) {
    const condError = validateEnum(data.condition, 'Condition', VALID_CONDITIONS, false);
    if (condError) errors.condition = condError;
  }
  
  // Warranty validation
  if (data.warranty_months !== undefined) {
    const warranty = Number(data.warranty_months);
    if (isNaN(warranty) || warranty < 0 || warranty > 120) {
      errors.warranty_months = 'Warranty must be between 0 and 120 months';
    }
  }
  
  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
}

// =====================================================
// OFFER VALIDATION
// =====================================================

const VALID_STOCK_STATUSES = ['in_stock', 'low_stock', 'out_of_stock', 'can_order'] as const;
const VALID_OFFER_STATUSES = ['pending', 'accepted', 'rejected', 'expired'] as const;

export function validateOffer(data: Record<string, unknown>): ValidationResult {
  const errors: Record<string, string> = {};
  
  // Required fields
  if (!isValidUuid(data.request_id)) {
    errors.request_id = 'Invalid request ID format';
  }
  
  if (!isValidUuid(data.shop_id)) {
    errors.shop_id = 'Invalid shop ID format';
  }
  
  // Price validation
  const priceError = validatePrice(data.price_cents, 'Price', 100000000);
  if (priceError) errors.price_cents = priceError;
  else if (data.price_cents === undefined || data.price_cents === null) {
    errors.price_cents = 'Price is required';
  }
  
  const deliveryError = validatePrice(data.delivery_fee_cents, 'Delivery fee', 10000000);
  if (deliveryError) errors.delivery_fee_cents = deliveryError;
  
  // ETA validation (max 90 days = 129600 minutes)
  if (data.eta_minutes !== undefined) {
    const eta = Number(data.eta_minutes);
    if (isNaN(eta) || eta < 0 || eta > 129600) {
      errors.eta_minutes = 'ETA must be between 0 and 90 days';
    }
  }
  
  // Stock status validation
  if (data.stock_status !== undefined) {
    const statusError = validateEnum(data.stock_status, 'Stock status', VALID_STOCK_STATUSES, false);
    if (statusError) errors.stock_status = statusError;
  }
  
  // Message validation
  const msgError = validateText(data.message, 'Message', { maxLength: 1000 });
  if (msgError) errors.message = msgError;
  
  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
}

// =====================================================
// ORDER STATUS VALIDATION
// =====================================================

const VALID_ORDER_STATUSES = [
  'pending', 'confirmed', 'preparing', 'processing',
  'shipped', 'out_for_delivery', 'delivered', 'cancelled'
] as const;

const VALID_STATUS_TRANSITIONS: Record<string, readonly string[]> = {
  'pending': ['confirmed', 'cancelled'],
  'confirmed': ['preparing', 'cancelled'],
  'preparing': ['processing', 'shipped', 'cancelled'],
  'processing': ['shipped', 'cancelled'],
  'shipped': ['out_for_delivery', 'delivered'],
  'out_for_delivery': ['delivered'],
  'delivered': [],
  'cancelled': []
};

export function validateOrderStatusTransition(
  currentStatus: string,
  newStatus: string
): ValidationResult {
  const errors: Record<string, string> = {};
  
  // Validate new status is valid enum
  const statusError = validateEnum(newStatus, 'Status', VALID_ORDER_STATUSES);
  if (statusError) {
    errors.status = statusError;
    return { isValid: false, errors };
  }
  
  // Validate transition is allowed
  const allowedTransitions = VALID_STATUS_TRANSITIONS[currentStatus] || [];
  if (!allowedTransitions.includes(newStatus)) {
    errors.status = `Cannot transition from '${currentStatus}' to '${newStatus}'. Allowed: ${allowedTransitions.join(', ') || 'none'}`;
  }
  
  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
}

// =====================================================
// PAYMENT VALIDATION
// =====================================================

export function validatePaymentInitialize(data: Record<string, unknown>): ValidationResult {
  const errors: Record<string, string> = {};
  
  if (!isValidUuid(data.order_id)) {
    errors.order_id = 'Invalid order ID format';
  }
  
  const amountError = validatePrice(data.amount, 'Amount', 200000000);
  if (amountError) errors.amount = amountError;
  else if (!data.amount) {
    errors.amount = 'Amount is required';
  }
  
  if (!isValidEmail(data.email)) {
    errors.email = 'Invalid email format';
  }
  
  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
}

// =====================================================
// REQUEST VALIDATION HELPER
// =====================================================

/**
 * Validate request body and return error response if invalid
 * 
 * Usage:
 * ```typescript
 * const validation = validateInventoryItem(body);
 * if (!validation.isValid) {
 *   return NextResponse.json({ 
 *     error: 'Validation failed', 
 *     details: validation.errors 
 *   }, { status: 400 });
 * }
 * ```
 */
export function createValidationErrorResponse(validation: ValidationResult) {
  return {
    error: 'Validation failed',
    details: validation.errors,
    message: Object.values(validation.errors)[0] // First error for simple display
  };
}
