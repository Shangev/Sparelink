import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

/**
 * Inventory Alerts API
 * 
 * Manages low stock alerts, reorder notifications, and inventory health checks.
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

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const shopId = searchParams.get('shop_id');

    if (!shopId) {
      return NextResponse.json({ error: 'Missing shop_id' }, { status: 400 });
    }

    // Get low stock items (stock <= reorder_level)
    const { data: lowStockItems, error: lowStockError } = await supabase
      .from('inventory')
      .select('*')
      .eq('shop_id', shopId)
      .lte('stock_quantity', supabase.rpc('get_reorder_level'))
      .order('stock_quantity', { ascending: true });

    // Get out of stock items
    const { data: outOfStockItems, error: outOfStockError } = await supabase
      .from('inventory')
      .select('*')
      .eq('shop_id', shopId)
      .eq('stock_quantity', 0);

    // Get items with high demand (many requests but low stock)
    const { data: highDemandItems, error: demandError } = await supabase
      .rpc('get_high_demand_low_stock', { p_shop_id: shopId });

    // Get inventory health summary
    const { data: healthSummary, error: healthError } = await supabase
      .from('inventory')
      .select('stock_quantity, reorder_level, status')
      .eq('shop_id', shopId);

    const summary = {
      total_items: healthSummary?.length || 0,
      in_stock: healthSummary?.filter(i => i.stock_quantity > 0).length || 0,
      out_of_stock: outOfStockItems?.length || 0,
      low_stock: lowStockItems?.length || 0,
      healthy: healthSummary?.filter(i => i.stock_quantity > (i.reorder_level || 5)).length || 0
    };

    // Generate alerts
    interface Alert {
      type: 'critical' | 'warning' | 'info';
      category: string;
      item_id: string;
      item_name: string;
      part_number?: string;
      current_stock?: number;
      reorder_level?: number;
      request_count?: number;
      message: string;
      action: string;
      created_at: string;
    }
    
    const alerts: Alert[] = [];

    // Critical: Out of stock alerts
    outOfStockItems?.forEach(item => {
      alerts.push({
        type: 'critical',
        category: 'out_of_stock',
        item_id: item.id,
        item_name: item.part_name,
        part_number: item.part_number,
        message: `${item.part_name} is out of stock`,
        action: 'Reorder immediately',
        created_at: new Date().toISOString()
      });
    });

    // Warning: Low stock alerts
    lowStockItems?.filter(i => i.stock_quantity > 0).forEach(item => {
      alerts.push({
        type: 'warning',
        category: 'low_stock',
        item_id: item.id,
        item_name: item.part_name,
        part_number: item.part_number,
        current_stock: item.stock_quantity,
        reorder_level: item.reorder_level || 5,
        message: `${item.part_name} is running low (${item.stock_quantity} remaining)`,
        action: 'Consider reordering',
        created_at: new Date().toISOString()
      });
    });

    // Info: High demand alerts
    highDemandItems?.forEach((item: any) => {
      alerts.push({
        type: 'info',
        category: 'high_demand',
        item_id: item.id,
        item_name: item.part_name,
        request_count: item.request_count,
        message: `${item.part_name} has high demand (${item.request_count} requests this month)`,
        action: 'Consider increasing stock',
        created_at: new Date().toISOString()
      });
    });

    return NextResponse.json({
      success: true,
      summary,
      alerts,
      low_stock_items: lowStockItems || [],
      out_of_stock_items: outOfStockItems || []
    });

  } catch (error) {
    console.error('Inventory alerts error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// Configure alert thresholds
export async function PUT(request: NextRequest) {
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

    const { shop_id, item_id, reorder_level, alert_enabled } = await request.json();

    if (!shop_id || !item_id) {
      return NextResponse.json({ error: 'Missing shop_id or item_id' }, { status: 400 });
    }

    const updates: any = { updated_at: new Date().toISOString() };
    if (reorder_level !== undefined) updates.reorder_level = reorder_level;
    if (alert_enabled !== undefined) updates.alert_enabled = alert_enabled;

    const { error: updateError } = await supabase
      .from('inventory')
      .update(updates)
      .eq('id', item_id)
      .eq('shop_id', shop_id);

    if (updateError) throw updateError;

    return NextResponse.json({ success: true });

  } catch (error) {
    console.error('Update alert settings error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
