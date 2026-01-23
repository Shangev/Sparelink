import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const paystackSecretKey = process.env.PAYSTACK_SECRET_KEY!;

/**
 * Verify Paystack Payment
 * 
 * Manually verify a payment status with Paystack.
 * Useful for checking payment status when webhook might have been missed.
 */

export async function GET(request: NextRequest) {
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

    const { searchParams } = new URL(request.url);
    const reference = searchParams.get('reference');

    if (!reference) {
      return NextResponse.json(
        { error: 'Missing reference parameter' },
        { status: 400 }
      );
    }

    // Verify with Paystack
    const paystackResponse = await fetch(
      `https://api.paystack.co/transaction/verify/${reference}`,
      {
        headers: {
          'Authorization': `Bearer ${paystackSecretKey}`
        }
      }
    );

    const paystackData = await paystackResponse.json();

    if (!paystackData.status) {
      return NextResponse.json(
        { error: paystackData.message || 'Verification failed' },
        { status: 400 }
      );
    }

    const transaction = paystackData.data;
    const orderId = transaction.metadata?.order_id;

    // Update order if payment was successful but not recorded
    if (transaction.status === 'success' && orderId) {
      const { data: order } = await supabase
        .from('orders')
        .select('payment_status')
        .eq('id', orderId)
        .single();

      if (order && order.payment_status !== 'paid') {
        await supabase
          .from('orders')
          .update({
            payment_status: 'paid',
            payment_reference: reference,
            payment_method: transaction.channel,
            paid_at: transaction.paid_at,
            updated_at: new Date().toISOString()
          })
          .eq('id', orderId);
      }
    }

    return NextResponse.json({
      success: true,
      status: transaction.status,
      amount: transaction.amount,
      currency: transaction.currency,
      paid_at: transaction.paid_at,
      channel: transaction.channel,
      reference: transaction.reference,
      order_id: orderId
    });

  } catch (error) {
    console.error('Payment verification error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
