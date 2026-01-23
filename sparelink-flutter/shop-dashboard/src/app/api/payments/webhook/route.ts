import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { createClient } from '@supabase/supabase-js';

// Initialize Supabase client with service role for webhook processing
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

/**
 * Paystack Webhook Handler
 * 
 * Handles payment events from Paystack:
 * - charge.success: Payment completed successfully
 * - charge.failed: Payment failed
 * - refund.processed: Refund completed
 * - transfer.success: Transfer to shop completed
 * 
 * Security: Validates webhook signature using Paystack secret key
 */

interface PaystackWebhookEvent {
  event: string;
  data: {
    id: number;
    domain: string;
    status: string;
    reference: string;
    amount: number;
    message: string | null;
    gateway_response: string;
    paid_at: string;
    created_at: string;
    channel: string;
    currency: string;
    metadata: {
      order_id?: string;
      shop_id?: string;
      customer_id?: string;
      invoice_number?: string;
    };
    customer: {
      id: number;
      email: string;
      customer_code: string;
      first_name: string | null;
      last_name: string | null;
      phone: string | null;
    };
    authorization: {
      authorization_code: string;
      bin: string;
      last4: string;
      exp_month: string;
      exp_year: string;
      channel: string;
      card_type: string;
      bank: string;
      country_code: string;
      brand: string;
      reusable: boolean;
    };
  };
}

// Verify Paystack webhook signature
function verifyPaystackSignature(payload: string, signature: string): boolean {
  const secret = process.env.PAYSTACK_SECRET_KEY;
  if (!secret) {
    console.error('PAYSTACK_SECRET_KEY not configured');
    return false;
  }
  
  const hash = crypto
    .createHmac('sha512', secret)
    .update(payload)
    .digest('hex');
  
  return hash === signature;
}

// Handle successful payment
async function handleChargeSuccess(data: PaystackWebhookEvent['data']) {
  const { reference, amount, metadata, customer, paid_at, authorization } = data;
  const orderId = metadata?.order_id;
  
  if (!orderId) {
    console.error('No order_id in payment metadata');
    return { success: false, error: 'Missing order_id' };
  }
  
  try {
    // Update order payment status
    const { error: orderError } = await supabase
      .from('orders')
      .update({
        payment_status: 'paid',
        payment_reference: reference,
        payment_method: authorization?.channel || 'card',
        payment_card_last4: authorization?.last4,
        payment_card_brand: authorization?.brand,
        paid_at: paid_at,
        updated_at: new Date().toISOString()
      })
      .eq('id', orderId);
    
    if (orderError) throw orderError;
    
    // Record payment in payments table
    const { error: paymentError } = await supabase
      .from('payments')
      .insert({
        order_id: orderId,
        shop_id: metadata?.shop_id,
        customer_id: metadata?.customer_id,
        amount_cents: amount,
        currency: 'ZAR',
        status: 'completed',
        provider: 'paystack',
        provider_reference: reference,
        provider_transaction_id: data.id.toString(),
        payment_method: authorization?.channel || 'card',
        card_last4: authorization?.last4,
        card_brand: authorization?.brand,
        customer_email: customer?.email,
        metadata: JSON.stringify(data),
        created_at: new Date().toISOString()
      });
    
    if (paymentError) throw paymentError;
    
    // Update customer total spend
    if (metadata?.customer_id) {
      await supabase.rpc('increment_customer_spend', {
        p_customer_id: metadata.customer_id,
        p_amount: amount
      });
    }
    
    // Create notification for shop
    if (metadata?.shop_id) {
      await supabase
        .from('shop_notifications')
        .insert({
          shop_id: metadata.shop_id,
          type: 'payment_received',
          title: 'Payment Received',
          message: `Payment of R${(amount / 100).toFixed(2)} received for order ${orderId.slice(0, 8)}`,
          data: JSON.stringify({ order_id: orderId, amount, reference }),
          created_at: new Date().toISOString()
        });
    }
    
    // Trigger invoice email (async)
    await fetch(`${process.env.NEXT_PUBLIC_APP_URL}/api/invoices/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ order_id: orderId })
    }).catch(err => console.error('Failed to trigger invoice email:', err));
    
    console.log(`Payment successful for order ${orderId}: R${(amount / 100).toFixed(2)}`);
    return { success: true };
    
  } catch (error) {
    console.error('Error processing successful payment:', error);
    return { success: false, error };
  }
}

// Handle failed payment
async function handleChargeFailed(data: PaystackWebhookEvent['data']) {
  const { reference, metadata, gateway_response } = data;
  const orderId = metadata?.order_id;
  
  if (!orderId) {
    return { success: false, error: 'Missing order_id' };
  }
  
  try {
    // Update order payment status
    await supabase
      .from('orders')
      .update({
        payment_status: 'failed',
        payment_error: gateway_response,
        updated_at: new Date().toISOString()
      })
      .eq('id', orderId);
    
    // Record failed payment attempt
    await supabase
      .from('payments')
      .insert({
        order_id: orderId,
        shop_id: metadata?.shop_id,
        amount_cents: data.amount,
        currency: 'ZAR',
        status: 'failed',
        provider: 'paystack',
        provider_reference: reference,
        error_message: gateway_response,
        metadata: JSON.stringify(data),
        created_at: new Date().toISOString()
      });
    
    // Notify shop of failed payment
    if (metadata?.shop_id) {
      await supabase
        .from('shop_notifications')
        .insert({
          shop_id: metadata.shop_id,
          type: 'payment_failed',
          title: 'Payment Failed',
          message: `Payment failed for order ${orderId.slice(0, 8)}: ${gateway_response}`,
          data: JSON.stringify({ order_id: orderId, error: gateway_response }),
          created_at: new Date().toISOString()
        });
    }
    
    console.log(`Payment failed for order ${orderId}: ${gateway_response}`);
    return { success: true };
    
  } catch (error) {
    console.error('Error processing failed payment:', error);
    return { success: false, error };
  }
}

// Handle refund
async function handleRefundProcessed(data: PaystackWebhookEvent['data']) {
  const { reference, amount, metadata } = data;
  const orderId = metadata?.order_id;
  
  if (!orderId) {
    return { success: false, error: 'Missing order_id' };
  }
  
  try {
    // Update order status
    await supabase
      .from('orders')
      .update({
        payment_status: 'refunded',
        refund_reference: reference,
        refund_amount_cents: amount,
        refunded_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', orderId);
    
    // Record refund
    await supabase
      .from('payments')
      .insert({
        order_id: orderId,
        shop_id: metadata?.shop_id,
        amount_cents: -amount, // Negative for refund
        currency: 'ZAR',
        status: 'refunded',
        provider: 'paystack',
        provider_reference: reference,
        payment_type: 'refund',
        metadata: JSON.stringify(data),
        created_at: new Date().toISOString()
      });
    
    console.log(`Refund processed for order ${orderId}: R${(amount / 100).toFixed(2)}`);
    return { success: true };
    
  } catch (error) {
    console.error('Error processing refund:', error);
    return { success: false, error };
  }
}

export async function POST(request: NextRequest) {
  try {
    const payload = await request.text();
    const signature = request.headers.get('x-paystack-signature');
    
    // Verify webhook signature
    if (!signature || !verifyPaystackSignature(payload, signature)) {
      console.error('Invalid Paystack webhook signature');
      return NextResponse.json(
        { error: 'Invalid signature' },
        { status: 401 }
      );
    }
    
    const event: PaystackWebhookEvent = JSON.parse(payload);
    console.log(`Received Paystack webhook: ${event.event}`);
    
    let result;
    
    switch (event.event) {
      case 'charge.success':
        result = await handleChargeSuccess(event.data);
        break;
        
      case 'charge.failed':
        result = await handleChargeFailed(event.data);
        break;
        
      case 'refund.processed':
        result = await handleRefundProcessed(event.data);
        break;
        
      case 'transfer.success':
        // Handle shop payout success
        console.log('Transfer to shop successful:', event.data.reference);
        result = { success: true };
        break;
        
      default:
        console.log(`Unhandled webhook event: ${event.event}`);
        result = { success: true };
    }
    
    return NextResponse.json({ received: true, ...result });
    
  } catch (error) {
    console.error('Webhook processing error:', error);
    return NextResponse.json(
      { error: 'Webhook processing failed' },
      { status: 500 }
    );
  }
}

// Paystack requires POST only
export async function GET() {
  return NextResponse.json(
    { error: 'Method not allowed' },
    { status: 405 }
  );
}
