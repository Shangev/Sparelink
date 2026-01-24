import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { 
  validateInventoryItem, 
  isValidUuid, 
  createValidationErrorResponse,
  sanitizeText 
} from '@/lib/validation';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

/**
 * Inventory CRUD API
 * 
 * Full Create, Read, Update, Delete operations for shop inventory.
 * 
 * Pass 4 Security Hardening:
 * - Server-side payload validation
 * - UUID format validation
 * - Text sanitization
 * - Price range validation
 */

// GET - List inventory items
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
    const category = searchParams.get('category');
    const search = searchParams.get('search');
    const status = searchParams.get('status');
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '50');

    // Pass 4: Validate shop_id is a valid UUID
    if (!shopId || !isValidUuid(shopId)) {
      return NextResponse.json({ error: 'Invalid or missing shop_id' }, { status: 400 });
    }

    let query = supabase
      .from('inventory')
      .select('*', { count: 'exact' })
      .eq('shop_id', shopId)
      .order('created_at', { ascending: false });

    if (category && category !== 'all') {
      query = query.eq('category', category);
    }

    if (status === 'in_stock') {
      query = query.gt('stock_quantity', 0);
    } else if (status === 'out_of_stock') {
      query = query.eq('stock_quantity', 0);
    } else if (status === 'low_stock') {
      query = query.lte('stock_quantity', 5).gt('stock_quantity', 0);
    }

    if (search) {
      query = query.or(`part_name.ilike.%${search}%,part_number.ilike.%${search}%,description.ilike.%${search}%`);
    }

    const offset = (page - 1) * limit;
    query = query.range(offset, offset + limit - 1);

    const { data, count, error } = await query;

    if (error) throw error;

    return NextResponse.json({
      success: true,
      items: data,
      pagination: {
        page,
        limit,
        total: count,
        total_pages: Math.ceil((count || 0) / limit)
      }
    });

  } catch (error) {
    console.error('Inventory list error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// POST - Create inventory item
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

    const body = await request.json();
    
    // Pass 4: Server-side payload validation
    const validation = validateInventoryItem(body);
    if (!validation.isValid) {
      return NextResponse.json(createValidationErrorResponse(validation), { status: 400 });
    }
    
    const {
      shop_id,
      part_name,
      part_number,
      category,
      description,
      cost_price,
      selling_price,
      stock_quantity,
      reorder_level,
      compatible_vehicles,
      condition,
      warranty_months,
      supplier,
      location
    } = body;
    
    // Sanitize text fields to prevent XSS
    const sanitizedPartName = sanitizeText(part_name);
    const sanitizedDescription = description ? sanitizeText(description) : null;

    const { data, error } = await supabase
      .from('inventory')
      .insert({
        shop_id,
        part_name: sanitizedPartName,  // Pass 4: Use sanitized value
        part_number: part_number || null,
        category,
        description: sanitizedDescription,  // Pass 4: Use sanitized value
        cost_price: cost_price || 0,
        selling_price: selling_price || 0,
        stock_quantity: stock_quantity || 0,
        reorder_level: reorder_level || 5,
        compatible_vehicles: compatible_vehicles || [],
        condition: condition || 'new',
        warranty_months: warranty_months || 0,
        supplier: supplier || null,
        location: location || null,
        status: stock_quantity > 0 ? 'in_stock' : 'out_of_stock',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) throw error;

    return NextResponse.json({ success: true, item: data }, { status: 201 });

  } catch (error) {
    console.error('Inventory create error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// PUT - Update inventory item
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

    const body = await request.json();
    const { id, shop_id, ...updates } = body;

    if (!id || !shop_id) {
      return NextResponse.json({ error: 'Missing id or shop_id' }, { status: 400 });
    }

    // Auto-update status based on stock
    if (updates.stock_quantity !== undefined) {
      updates.status = updates.stock_quantity > 0 ? 'in_stock' : 'out_of_stock';
    }

    updates.updated_at = new Date().toISOString();

    const { data, error } = await supabase
      .from('inventory')
      .update(updates)
      .eq('id', id)
      .eq('shop_id', shop_id)
      .select()
      .single();

    if (error) throw error;

    return NextResponse.json({ success: true, item: data });

  } catch (error) {
    console.error('Inventory update error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// DELETE - Remove inventory item
export async function DELETE(request: NextRequest) {
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
    const id = searchParams.get('id');
    const shopId = searchParams.get('shop_id');

    if (!id || !shopId) {
      return NextResponse.json({ error: 'Missing id or shop_id' }, { status: 400 });
    }

    const { error } = await supabase
      .from('inventory')
      .delete()
      .eq('id', id)
      .eq('shop_id', shopId);

    if (error) throw error;

    return NextResponse.json({ success: true });

  } catch (error) {
    console.error('Inventory delete error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
