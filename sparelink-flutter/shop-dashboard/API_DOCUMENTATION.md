# Sparelink Shop Dashboard API Documentation

> **Version:** 1.0.0  
> **Last Updated:** January 23, 2026  
> **Base URL:** `https://your-domain.com/api`

## Table of Contents

1. [Authentication](#authentication)
2. [Payment Processing](#payment-processing)
3. [Invoice Management](#invoice-management)
4. [Inventory Management](#inventory-management)
5. [Customer CRM](#customer-crm)
6. [Analytics](#analytics)
7. [Error Handling](#error-handling)

---

## Authentication

All API endpoints require authentication via Supabase JWT tokens.

### Headers

```
Authorization: Bearer <supabase_jwt_token>
Content-Type: application/json
```

---

## Payment Processing

### Initialize Payment

Creates a Paystack payment session for an order.

```
POST /api/payments/initialize
```

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | UUID | Yes | The order to process payment for |
| `amount_cents` | integer | Yes | Amount in cents (e.g., 150000 = R1,500) |
| `email` | string | Yes | Customer email for payment receipt |
| `shop_id` | UUID | Yes | Shop processing the payment |
| `customer_id` | UUID | No | Customer ID for tracking |
| `callback_url` | string | No | URL to redirect after payment |

#### Example Request

```json
{
  "order_id": "123e4567-e89b-12d3-a456-426614174000",
  "amount_cents": 150000,
  "email": "customer@example.com",
  "shop_id": "223e4567-e89b-12d3-a456-426614174001",
  "customer_id": "323e4567-e89b-12d3-a456-426614174002"
}
```

#### Response

```json
{
  "success": true,
  "authorization_url": "https://checkout.paystack.com/xxx",
  "access_code": "xxx",
  "reference": "SPL-123e4567-1674556800000"
}
```

---

### Verify Payment

Manually verify a payment status with Paystack.

```
GET /api/payments/verify?reference=<payment_reference>
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `reference` | string | Yes | The payment reference |

#### Response

```json
{
  "success": true,
  "status": "success",
  "amount": 150000,
  "currency": "ZAR",
  "paid_at": "2026-01-23T10:00:00.000Z",
  "channel": "card",
  "reference": "SPL-123e4567-1674556800000",
  "order_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

---

### Payment Webhook

Receives payment events from Paystack.

```
POST /api/payments/webhook
```

#### Headers

```
x-paystack-signature: <hmac_sha512_signature>
```

#### Supported Events

| Event | Description |
|-------|-------------|
| `charge.success` | Payment completed successfully |
| `charge.failed` | Payment failed |
| `refund.processed` | Refund completed |
| `transfer.success` | Shop payout completed |

#### Response

```json
{
  "received": true,
  "success": true
}
```

---

## Invoice Management

### Generate Invoice Number

Creates a unique sequential invoice number.

```
POST /api/invoices/generate
```

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | UUID | Yes | Order to generate invoice for |
| `shop_id` | UUID | Yes | Shop ID |

#### Response

```json
{
  "success": true,
  "invoice_number": "INV-2026-00042"
}
```

---

### Send Invoice Email

Generates and emails a PDF invoice to the customer.

```
POST /api/invoices/send
```

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | UUID | Yes | Order to send invoice for |

#### Response

```json
{
  "success": true,
  "message": "Invoice sent successfully",
  "email_id": "resend_email_id"
}
```

---

## Inventory Management

### List Inventory

Retrieve inventory items with filtering and pagination.

```
GET /api/inventory
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `shop_id` | UUID | Yes | Shop ID |
| `category` | string | No | Filter by category (e.g., "Engine", "Brake") |
| `status` | string | No | Filter by status: `in_stock`, `out_of_stock`, `low_stock` |
| `search` | string | No | Search by part name or number |
| `page` | integer | No | Page number (default: 1) |
| `limit` | integer | No | Items per page (default: 50) |

#### Response

```json
{
  "success": true,
  "items": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "part_name": "Brake Pad Set",
      "part_number": "BP-001",
      "category": "Brake",
      "stock_quantity": 10,
      "reorder_level": 5,
      "cost_price": 25000,
      "selling_price": 45000,
      "status": "in_stock"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 150,
    "total_pages": 3
  }
}
```

---

### Create Inventory Item

Add a new part to inventory.

```
POST /api/inventory
```

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `shop_id` | UUID | Yes | Shop ID |
| `part_name` | string | Yes | Part name |
| `category` | string | Yes | Category |
| `part_number` | string | No | Part number/SKU |
| `description` | string | No | Part description |
| `cost_price` | integer | No | Cost in cents |
| `selling_price` | integer | No | Selling price in cents |
| `stock_quantity` | integer | No | Initial stock (default: 0) |
| `reorder_level` | integer | No | Low stock threshold (default: 5) |
| `compatible_vehicles` | array | No | Array of compatible vehicles |
| `condition` | string | No | "new", "used", or "refurbished" |
| `warranty_months` | integer | No | Warranty period |
| `supplier` | string | No | Supplier name |
| `location` | string | No | Warehouse location |

#### Example Request

```json
{
  "shop_id": "223e4567-e89b-12d3-a456-426614174001",
  "part_name": "Oil Filter",
  "part_number": "OF-002",
  "category": "Engine",
  "cost_price": 5000,
  "selling_price": 12000,
  "stock_quantity": 25,
  "compatible_vehicles": [
    {"make": "Toyota", "model": "Corolla", "year_from": 2015, "year_to": 2022}
  ]
}
```

#### Response

```json
{
  "success": true,
  "item": { ... }
}
```

---

### Update Inventory Item

```
PUT /api/inventory
```

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | UUID | Yes | Item ID |
| `shop_id` | UUID | Yes | Shop ID |
| `...` | any | No | Any field to update |

---

### Delete Inventory Item

```
DELETE /api/inventory?id=<item_id>&shop_id=<shop_id>
```

---

### Inventory Alerts

Get low stock and out of stock alerts.

```
GET /api/inventory/alerts?shop_id=<shop_id>
```

#### Response

```json
{
  "success": true,
  "summary": {
    "total_items": 150,
    "in_stock": 120,
    "out_of_stock": 10,
    "low_stock": 20,
    "healthy": 100
  },
  "alerts": [
    {
      "type": "critical",
      "category": "out_of_stock",
      "item_name": "Brake Disc",
      "message": "Brake Disc is out of stock",
      "action": "Reorder immediately"
    },
    {
      "type": "warning",
      "category": "low_stock",
      "item_name": "Oil Filter",
      "current_stock": 3,
      "reorder_level": 5,
      "message": "Oil Filter is running low (3 remaining)",
      "action": "Consider reordering"
    }
  ],
  "low_stock_items": [...],
  "out_of_stock_items": [...]
}
```

---

## Customer CRM

### List Customers

```
GET /api/customers
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `shop_id` | UUID | Yes | Shop ID |
| `tier` | string | No | Filter by tier: `bronze`, `silver`, `gold`, `platinum` |
| `search` | string | No | Search by name, email, or phone |
| `page` | integer | No | Page number |
| `limit` | integer | No | Items per page |

#### Response

```json
{
  "success": true,
  "customers": [
    {
      "id": "xxx",
      "customer_id": "xxx",
      "loyalty_tier": "gold",
      "total_spend": 2500000,
      "order_count": 15,
      "profiles": {
        "full_name": "John Doe",
        "email": "john@example.com",
        "phone": "+27821234567"
      }
    }
  ],
  "tier_summary": {
    "platinum": 5,
    "gold": 20,
    "silver": 45,
    "bronze": 130
  },
  "pagination": { ... }
}
```

---

### Get Customer Order History

```
GET /api/customers/<customer_id>/orders?shop_id=<shop_id>
```

#### Response

```json
{
  "success": true,
  "orders": [...],
  "stats": {
    "total_orders": 15,
    "total_spent": 2500000,
    "average_order": 166666,
    "first_order": "2025-06-15T10:00:00Z",
    "last_order": "2026-01-20T14:30:00Z",
    "completed_orders": 14,
    "pending_orders": 1
  }
}
```

---

### Update Customer

```
PUT /api/customers
```

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | UUID | Yes | Shop-customer relationship ID |
| `shop_id` | UUID | Yes | Shop ID |
| `notes` | string | No | Customer notes |
| `loyalty_tier` | string | No | Manual tier override |
| `tags` | array | No | Customer tags |

---

## Analytics

### Get Analytics Data

```
GET /api/analytics?shop_id=<shop_id>&period=<period>
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `shop_id` | UUID | Yes | Shop ID |
| `period` | string | No | `week`, `month`, `quarter`, `year` (default: month) |

#### Response

```json
{
  "success": true,
  "period": "month",
  "kpis": {
    "total_revenue": 5000000,
    "total_orders": 45,
    "total_quotes": 120,
    "conversion_rate": 37.5,
    "average_order_value": 111111
  },
  "revenue_by_day": {
    "2026-01-01": 150000,
    "2026-01-02": 200000
  },
  "top_categories": [
    {"category": "Engine", "revenue": 1500000},
    {"category": "Brake", "revenue": 1200000}
  ]
}
```

---

## Error Handling

### Error Response Format

```json
{
  "error": "Error message description"
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| `200` | Success |
| `201` | Created |
| `400` | Bad Request - Invalid parameters |
| `401` | Unauthorized - Invalid or missing token |
| `404` | Not Found |
| `405` | Method Not Allowed |
| `500` | Internal Server Error |

---

## Loyalty Tier Thresholds

| Tier | Minimum Spend (ZAR) |
|------|---------------------|
| Bronze | R0 |
| Silver | R5,000 |
| Gold | R20,000 |
| Platinum | R50,000 |

---

## Rate Limits

- **Standard endpoints:** 100 requests/minute
- **Webhook endpoints:** 1000 requests/minute
- **Analytics endpoints:** 30 requests/minute

---

## Environment Variables

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx

# Paystack
PAYSTACK_SECRET_KEY=sk_live_xxx
PAYSTACK_PUBLIC_KEY=pk_live_xxx

# Email (Resend)
RESEND_API_KEY=re_xxx

# App
NEXT_PUBLIC_APP_URL=https://your-domain.com
```

---

## Webhook Configuration

### Paystack Webhook URL

Configure in Paystack Dashboard:
```
https://your-domain.com/api/payments/webhook
```

### Supported Events to Enable

- `charge.success`
- `charge.failed`
- `refund.processed`
- `transfer.success`

---

## Support

For API support, contact: api-support@sparelink.co.za
