import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

/**
 * Customer/CRM API
 * 
 * Manages customer database with loyalty tiers, order history, and notes.
 */

// GET - List customers with filtering
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
    const tier = searchParams.get('tier');
    const search = searchParams.get('search');
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '50');

    if (!shopId) {
      return NextResponse.json({ error: 'Missing shop_id' }, { status: 400 });
    }

    let query = supabase
      .from('shop_customers')
      .select(`
        *,
        profiles:customer_id (full_name, email, phone, avatar_url)
      `, { count: 'exact' })
      .eq('shop_id', shopId)
      .order('total_spend', { ascending: false });

    if (tier && tier !== 'all') {
      query = query.eq('loyalty_tier', tier);
    }

    if (search) {
      // Search in joined profiles
      query = query.or(`profiles.full_name.ilike.%${search}%,profiles.email.ilike.%${search}%,profiles.phone.ilike.%${search}%`);
    }

    const offset = (page - 1) * limit;
    query = query.range(offset, offset + limit - 1);

    const { data, count, error } = await query;

    if (error) throw error;

    // Calculate tier summary
    const { data: tierSummary } = await supabase
      .from('shop_customers')
      .select('loyalty_tier')
      .eq('shop_id', shopId);

    const tiers = {
      platinum: tierSummary?.filter(c => c.loyalty_tier === 'platinum').length || 0,
      gold: tierSummary?.filter(c => c.loyalty_tier === 'gold').length || 0,
      silver: tierSummary?.filter(c => c.loyalty_tier === 'silver').length || 0,
      bronze: tierSummary?.filter(c => c.loyalty_tier === 'bronze').length || 0
    };

    return NextResponse.json({
      success: true,
      customers: data,
      tier_summary: tiers,
      pagination: {
        page,
        limit,
        total: count,
        total_pages: Math.ceil((count || 0) / limit)
      }
    });

  } catch (error) {
    console.error('Customers list error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// POST - Create/link customer to shop
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

    const { shop_id, customer_id, notes } = await request.json();

    if (!shop_id || !customer_id) {
      return NextResponse.json({ error: 'Missing shop_id or customer_id' }, { status: 400 });
    }

    // Check if customer relationship already exists
    const { data: existing } = await supabase
      .from('shop_customers')
      .select('id')
      .eq('shop_id', shop_id)
      .eq('customer_id', customer_id)
      .single();

    if (existing) {
      return NextResponse.json({ error: 'Customer already linked' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('shop_customers')
      .insert({
        shop_id,
        customer_id,
        notes: notes || null,
        total_spend: 0,
        order_count: 0,
        loyalty_tier: 'bronze',
        first_order_at: null,
        last_order_at: null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) throw error;

    return NextResponse.json({ success: true, customer: data }, { status: 201 });

  } catch (error) {
    console.error('Customer create error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// PUT - Update customer notes or tier
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

    const { id, shop_id, notes, loyalty_tier, tags } = await request.json();

    if (!id || !shop_id) {
      return NextResponse.json({ error: 'Missing id or shop_id' }, { status: 400 });
    }

    const updates: any = { updated_at: new Date().toISOString() };
    if (notes !== undefined) updates.notes = notes;
    if (loyalty_tier !== undefined) updates.loyalty_tier = loyalty_tier;
    if (tags !== undefined) updates.tags = tags;

    const { data, error } = await supabase
      .from('shop_customers')
      .update(updates)
      .eq('id', id)
      .eq('shop_id', shop_id)
      .select()
      .single();

    if (error) throw error;

    return NextResponse.json({ success: true, customer: data });

  } catch (error) {
    console.error('Customer update error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
