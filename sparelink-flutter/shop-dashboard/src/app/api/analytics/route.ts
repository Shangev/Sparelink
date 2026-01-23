import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

/**
 * Analytics/Business Intelligence API
 * 
 * Provides revenue data, top products, staff performance, and KPIs.
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
    const period = searchParams.get('period') || 'month'; // week, month, quarter, year

    if (!shopId) {
      return NextResponse.json({ error: 'Missing shop_id' }, { status: 400 });
    }

    // Calculate date range
    const now = new Date();
    let startDate: Date;
    switch (period) {
      case 'week':
        startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'quarter':
        startDate = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
        break;
      case 'year':
        startDate = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
        break;
      default: // month
        startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    }

    // Get orders in period
    const { data: orders } = await supabase
      .from('orders')
      .select('id, total_cents, status, payment_status, created_at')
      .eq('shop_id', shopId)
      .gte('created_at', startDate.toISOString());

    // Get quotes in period
    const { data: quotes } = await supabase
      .from('quotes')
      .select('id, price_cents, status, created_at')
      .eq('shop_id', shopId)
      .gte('created_at', startDate.toISOString());

    // Calculate KPIs
    const totalRevenue = orders?.filter(o => o.payment_status === 'paid')
      .reduce((sum, o) => sum + (o.total_cents || 0), 0) || 0;
    const totalOrders = orders?.length || 0;
    const totalQuotes = quotes?.length || 0;
    const acceptedQuotes = quotes?.filter(q => q.status === 'accepted').length || 0;
    const conversionRate = totalQuotes > 0 ? (acceptedQuotes / totalQuotes * 100) : 0;

    // Revenue by day
    const revenueByDay: Record<string, number> = {};
    orders?.filter(o => o.payment_status === 'paid').forEach(order => {
      const day = order.created_at.split('T')[0];
      revenueByDay[day] = (revenueByDay[day] || 0) + (order.total_cents || 0);
    });

    // Top selling categories
    const { data: topCategories } = await supabase
      .from('orders')
      .select('part_requests:request_id (part_category), total_cents')
      .eq('shop_id', shopId)
      .eq('payment_status', 'paid')
      .gte('created_at', startDate.toISOString());

    const categoryRevenue: Record<string, number> = {};
    topCategories?.forEach((order: any) => {
      const category = order.part_requests?.part_category || 'Other';
      categoryRevenue[category] = (categoryRevenue[category] || 0) + (order.total_cents || 0);
    });

    const topCategoriesSorted = Object.entries(categoryRevenue)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([category, revenue]) => ({ category, revenue }));

    return NextResponse.json({
      success: true,
      period,
      kpis: {
        total_revenue: totalRevenue,
        total_orders: totalOrders,
        total_quotes: totalQuotes,
        conversion_rate: Math.round(conversionRate * 10) / 10,
        average_order_value: totalOrders > 0 ? Math.round(totalRevenue / totalOrders) : 0
      },
      revenue_by_day: revenueByDay,
      top_categories: topCategoriesSorted
    });

  } catch (error) {
    console.error('Analytics error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
