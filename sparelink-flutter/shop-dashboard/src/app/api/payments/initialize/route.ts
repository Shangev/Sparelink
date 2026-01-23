import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const paystackSecretKey = process.env.PAYSTACK_SECRET_KEY!;

/**
 * Initialize Paystack Payment
 * 
 * Creates a payment session with Paystack and returns the authorization URL
 * for the customer to complete payment.
 */

interface InitializePaymentRequest {
  order_id: string;
  amount_cents: number;
  email: string;
  shop_id: string;
  customer_id?: string;
  callback_url?: string;
}

export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get('authorization');
    if (!authHeader) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    // Verify user is authenticated
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body: InitializePaymentRequest = await request.json();
    const { order_id, amount_cents, email, shop_id, customer_id, callback_url } = body;

    // Validate required fields
    if (!order_id || !amount_cents || !email || !shop_id) {
      return NextResponse.json(
        { error: 'Missing required fields: order_id, amount_cents, email, shop_id' },
        { status: 400 }
      );
    }

    // Verify the order exists and belongs to the shop
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('id, total_cents, payment_status, shop_id')
      .eq('id', order_id)
      .eq('shop_id', shop_id)
      .single();

    if (orderError || !order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 });
    }

    if (order.payment_status === 'paid') {
      return NextResponse.json({ error: 'Order already paid' }, { status: 400 });
    }

    // Generate unique reference
    const reference = `SPL-${order_id.slice(0, 8)}-${Date.now()}`;

    // Initialize payment with Paystack
    const paystackResponse = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${paystackSecretKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email,
        amount: amount_cents, // Paystack expects amount in kobo/cents
        currency: 'ZAR',
        reference,
        callback_url: callback_url || `${process.env.NEXT_PUBLIC_APP_URL}/dashboard/orders?payment=success`,
        metadata: {
          order_id,
          shop_id,
          customer_id,
          invoice_number: `INV-${order_id.slice(0, 8).toUpperCase()}`
        },
        channels: ['card', 'bank', 'bank_transfer', 'eft']
      })
    });

    const paystackData = await paystackResponse.json();

    if (!paystackData.status) {
      console.error('Paystack initialization failed:', paystackData);
      return NextResponse.json(
        { error: paystackData.message || 'Payment initialization failed' },
        { status: 400 }
      );
    }

    // Update order with payment reference
    await supabase
      .from('orders')
      .update({
        payment_reference: reference,
        payment_status: 'pending',
        updated_at: new Date().toISOString()
      })
      .eq('id', order_id);

    // Log payment initiation
    await supabase
      .from('payment_logs')
      .insert({
        order_id,
        shop_id,
        action: 'payment_initialized',
        reference,
        amount_cents,
        provider: 'paystack',
        metadata: JSON.stringify(paystackData.data),
        created_at: new Date().toISOString()
      });

    return NextResponse.json({
      success: true,
      authorization_url: paystackData.data.authorization_url,
      access_code: paystackData.data.access_code,
      reference
    });

  } catch (error) {
    console.error('Payment initialization error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
