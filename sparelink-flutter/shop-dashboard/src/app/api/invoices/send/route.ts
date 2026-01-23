import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

/**
 * Send Invoice Email
 * 
 * Generates and sends a professional PDF invoice to the customer via email.
 * Uses Resend/SendGrid for email delivery.
 */

interface InvoiceData {
  order_id: string;
  invoice_number: string;
  shop_name: string;
  shop_address: string;
  shop_email: string;
  shop_phone: string;
  customer_name: string;
  customer_email: string;
  customer_address: string;
  items: Array<{
    description: string;
    vehicle: string;
    quantity: number;
    unit_price: number;
    total: number;
  }>;
  subtotal: number;
  vat: number;
  total: number;
  payment_status: string;
  payment_reference?: string;
  paid_at?: string;
  created_at: string;
}

function generateInvoiceHTML(data: InvoiceData): string {
  const itemsHTML = data.items.map(item => `
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #eee;">
        <div style="font-weight: 500;">${item.description}</div>
        <div style="font-size: 12px; color: #666;">${item.vehicle}</div>
      </td>
      <td style="padding: 12px; border-bottom: 1px solid #eee; text-align: center;">${item.quantity}</td>
      <td style="padding: 12px; border-bottom: 1px solid #eee; text-align: right;">R${item.unit_price.toFixed(2)}</td>
      <td style="padding: 12px; border-bottom: 1px solid #eee; text-align: right; font-weight: 500;">R${item.total.toFixed(2)}</td>
    </tr>
  `).join('');

  const paidStamp = data.payment_status === 'paid' ? `
    <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-30deg); 
                font-size: 72px; font-weight: bold; color: rgba(16, 185, 129, 0.2); 
                border: 8px solid rgba(16, 185, 129, 0.2); padding: 10px 30px; border-radius: 10px;">
      PAID
    </div>
  ` : '';

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Invoice ${data.invoice_number}</title>
  <style>
    body { font-family: 'Helvetica Neue', Arial, sans-serif; margin: 0; padding: 40px; color: #333; }
    .invoice-container { max-width: 800px; margin: 0 auto; position: relative; }
    .header { display: flex; justify-content: space-between; margin-bottom: 40px; padding-bottom: 20px; border-bottom: 3px solid #10b981; }
    .company-name { font-size: 28px; font-weight: bold; color: #10b981; }
    .company-details { font-size: 12px; color: #666; margin-top: 5px; }
    .invoice-title { font-size: 36px; font-weight: bold; color: #333; text-align: right; }
    .invoice-number { font-size: 14px; color: #666; text-align: right; margin-top: 5px; }
    .parties { display: flex; justify-content: space-between; margin-bottom: 30px; }
    .party { width: 45%; }
    .party-title { font-size: 12px; color: #666; text-transform: uppercase; margin-bottom: 10px; font-weight: 600; }
    .party-name { font-size: 18px; font-weight: bold; margin-bottom: 5px; }
    .party-details { font-size: 14px; color: #666; line-height: 1.6; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
    th { background: #f8f9fa; padding: 12px; text-align: left; font-size: 12px; text-transform: uppercase; color: #666; font-weight: 600; }
    .totals { margin-left: auto; width: 300px; }
    .totals table { margin-bottom: 0; }
    .totals td { padding: 8px 0; }
    .totals .label { color: #666; }
    .totals .value { text-align: right; font-weight: 500; }
    .grand-total td { font-size: 18px; font-weight: bold; border-top: 2px solid #333; padding-top: 12px; }
    .payment-info { margin-top: 30px; padding: 15px; background: #f0fdf4; border-radius: 8px; border: 1px solid #bbf7d0; }
    .payment-info .title { color: #166534; font-weight: 600; margin-bottom: 5px; }
    .payment-info .details { color: #15803d; font-size: 14px; }
    .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #666; text-align: center; }
  </style>
</head>
<body>
  <div class="invoice-container">
    ${paidStamp}
    
    <div class="header">
      <div>
        <div class="company-name">${data.shop_name}</div>
        <div class="company-details">
          ${data.shop_address}<br>
          ${data.shop_phone} | ${data.shop_email}
        </div>
      </div>
      <div>
        <div class="invoice-title">INVOICE</div>
        <div class="invoice-number">
          ${data.invoice_number}<br>
          Date: ${new Date(data.created_at).toLocaleDateString('en-ZA')}
        </div>
      </div>
    </div>

    <div class="parties">
      <div class="party">
        <div class="party-title">Bill To</div>
        <div class="party-name">${data.customer_name}</div>
        <div class="party-details">${data.customer_address}<br>${data.customer_email}</div>
      </div>
      <div class="party">
        <div class="party-title">Invoice Details</div>
        <div class="party-details">
          <strong>Invoice #:</strong> ${data.invoice_number}<br>
          <strong>Date:</strong> ${new Date(data.created_at).toLocaleDateString('en-ZA')}<br>
          <strong>Status:</strong> ${data.payment_status === 'paid' ? 'Paid' : 'Pending'}
        </div>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th>Description</th>
          <th style="text-align: center;">Qty</th>
          <th style="text-align: right;">Unit Price</th>
          <th style="text-align: right;">Amount</th>
        </tr>
      </thead>
      <tbody>
        ${itemsHTML}
      </tbody>
    </table>

    <div class="totals">
      <table>
        <tr>
          <td class="label">Subtotal</td>
          <td class="value">R${data.subtotal.toFixed(2)}</td>
        </tr>
        <tr>
          <td class="label">VAT (15%)</td>
          <td class="value">R${data.vat.toFixed(2)}</td>
        </tr>
        <tr class="grand-total">
          <td>Total</td>
          <td class="value">R${data.total.toFixed(2)}</td>
        </tr>
      </table>
    </div>

    ${data.payment_status === 'paid' && data.payment_reference ? `
    <div class="payment-info">
      <div class="title">Payment Received</div>
      <div class="details">
        Reference: ${data.payment_reference}<br>
        Date: ${data.paid_at ? new Date(data.paid_at).toLocaleDateString('en-ZA') : 'N/A'}
      </div>
    </div>
    ` : ''}

    <div class="footer">
      <p>Thank you for your business!</p>
      <p>For queries, contact us at ${data.shop_email}</p>
    </div>
  </div>
</body>
</html>
  `;
}

export async function POST(request: NextRequest) {
  try {
    const { order_id } = await request.json();

    if (!order_id) {
      return NextResponse.json({ error: 'Missing order_id' }, { status: 400 });
    }

    // Fetch order with related data
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select(`
        *,
        shops:shop_id (name, address, email, phone),
        part_requests:request_id (
          part_category,
          part_description,
          vehicle_make,
          vehicle_model,
          vehicle_year,
          profiles:user_id (full_name, email, phone)
        )
      `)
      .eq('id', order_id)
      .single();

    if (orderError || !order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 });
    }

    const shop = order.shops;
    const request_data = order.part_requests;
    const customer = request_data?.profiles;

    if (!customer?.email) {
      return NextResponse.json({ error: 'Customer email not found' }, { status: 400 });
    }

    const subtotal = (order.total_cents || 0) / 100;
    const vat = subtotal * 0.15;
    const total = subtotal + vat;

    const invoiceData: InvoiceData = {
      order_id,
      invoice_number: order.invoice_number || `INV-${order_id.slice(0, 8).toUpperCase()}`,
      shop_name: shop?.name || 'Sparelink Shop',
      shop_address: shop?.address || '',
      shop_email: shop?.email || 'support@sparelink.co.za',
      shop_phone: shop?.phone || '',
      customer_name: customer?.full_name || 'Customer',
      customer_email: customer?.email,
      customer_address: order.delivery_address || '',
      items: [{
        description: request_data?.part_category || 'Auto Part',
        vehicle: `${request_data?.vehicle_make || ''} ${request_data?.vehicle_model || ''} ${request_data?.vehicle_year || ''}`.trim(),
        quantity: 1,
        unit_price: subtotal,
        total: subtotal
      }],
      subtotal,
      vat,
      total,
      payment_status: order.payment_status,
      payment_reference: order.payment_reference,
      paid_at: order.paid_at,
      created_at: order.created_at
    };

    const invoiceHTML = generateInvoiceHTML(invoiceData);

    // Send email using Resend (or your preferred email service)
    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: `${shop?.name || 'Sparelink'} <invoices@sparelink.co.za>`,
        to: customer.email,
        subject: `Invoice ${invoiceData.invoice_number} from ${shop?.name || 'Sparelink'}`,
        html: invoiceHTML
      })
    });

    const emailResult = await emailResponse.json();

    if (!emailResponse.ok) {
      console.error('Email send failed:', emailResult);
      return NextResponse.json({ error: 'Failed to send email' }, { status: 500 });
    }

    // Log the email sent
    await supabase
      .from('invoice_emails')
      .insert({
        order_id,
        invoice_number: invoiceData.invoice_number,
        recipient_email: customer.email,
        sent_at: new Date().toISOString(),
        email_provider_id: emailResult.id
      });

    return NextResponse.json({
      success: true,
      message: 'Invoice sent successfully',
      email_id: emailResult.id
    });

  } catch (error) {
    console.error('Invoice send error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
