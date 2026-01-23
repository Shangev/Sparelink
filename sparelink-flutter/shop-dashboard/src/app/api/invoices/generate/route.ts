import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

/**
 * Generate Invoice Number
 * 
 * Creates a unique invoice number for an order and stores it.
 */

export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get('authorization');
    if (!authHeader) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { order_id, shop_id } = await request.json();

    if (!order_id || !shop_id) {
      return NextResponse.json({ error: 'Missing order_id or shop_id' }, { status: 400 });
    }

    // Get the next invoice number for this shop
    const { data: lastInvoice } = await supabase
      .from('orders')
      .select('invoice_number')
      .eq('shop_id', shop_id)
      .not('invoice_number', 'is', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    let nextNumber = 1;
    if (lastInvoice?.invoice_number) {
      const match = lastInvoice.invoice_number.match(/(\d+)$/);
      if (match) {
        nextNumber = parseInt(match[1]) + 1;
      }
    }

    const invoiceNumber = `INV-${new Date().getFullYear()}-${String(nextNumber).padStart(5, '0')}`;

    // Update the order with the invoice number
    const { error: updateError } = await supabase
      .from('orders')
      .update({ 
        invoice_number: invoiceNumber,
        updated_at: new Date().toISOString()
      })
      .eq('id', order_id)
      .eq('shop_id', shop_id);

    if (updateError) {
      throw updateError;
    }

    return NextResponse.json({
      success: true,
      invoice_number: invoiceNumber
    });

  } catch (error) {
    console.error('Invoice generation error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
