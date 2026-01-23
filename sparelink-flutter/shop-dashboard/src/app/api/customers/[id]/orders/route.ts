import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

/**
 * Customer Order History API
 * 
 * Retrieves order history for a specific customer.
 */

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
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

    const customerId = params.id;
    const { searchParams } = new URL(request.url);
    const shopId = searchParams.get('shop_id');

    if (!shopId) {
      return NextResponse.json({ error: 'Missing shop_id' }, { status: 400 });
    }

    // Get orders for this customer at this shop
    const { data: orders, error: ordersError } = await supabase
      .from('orders')
      .select(`
        id,
        total_cents,
        status,
        payment_status,
        created_at,
        part_requests:request_id (
          part_category,
          vehicle_make,
          vehicle_model
        )
      `)
      .eq('shop_id', shopId)
      .eq('customer_id', customerId)
      .order('created_at', { ascending: false });

    if (ordersError) throw ordersError;

    // Calculate customer stats
    const stats = {
      total_orders: orders?.length || 0,
      total_spent: orders?.reduce((sum, o) => sum + (o.total_cents || 0), 0) || 0,
      average_order: 0,
      first_order: orders?.[orders.length - 1]?.created_at || null,
      last_order: orders?.[0]?.created_at || null,
      completed_orders: orders?.filter(o => o.status === 'delivered').length || 0,
      pending_orders: orders?.filter(o => ['pending', 'processing', 'shipped'].includes(o.status)).length || 0
    };

    if (stats.total_orders > 0) {
      stats.average_order = Math.round(stats.total_spent / stats.total_orders);
    }

    return NextResponse.json({
      success: true,
      orders,
      stats
    });

  } catch (error) {
    console.error('Customer orders error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
