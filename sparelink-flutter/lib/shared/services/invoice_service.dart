import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../models/marketplace.dart';

/// Invoice PDF Generation Service
/// Generates professional PDF invoices for orders
class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  /// Generate PDF invoice for an order
  Future<Uint8List> generateInvoice(Order order) async {
    final pdf = pw.Document();
    
    final offer = order.offer;
    final shop = offer?.shop;
    
    // Calculate amounts
    final partPrice = (offer?.priceCents ?? 0) / 100;
    final deliveryFee = (offer?.deliveryFeeCents ?? 0) / 100;
    final subtotal = partPrice + deliveryFee;
    final vat = subtotal * 0.15;
    final total = subtotal + vat;
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(order, shop),
              pw.SizedBox(height: 30),
              
              // Invoice Details
              _buildInvoiceDetails(order),
              pw.SizedBox(height: 30),
              
              // Bill To / Ship To
              _buildAddresses(order, shop),
              pw.SizedBox(height: 30),
              
              // Items Table
              _buildItemsTable(order, offer, partPrice, deliveryFee),
              pw.SizedBox(height: 20),
              
              // Totals
              _buildTotals(subtotal, vat, total),
              pw.SizedBox(height: 30),
              
              // Payment Info
              if (order.paymentStatus == 'paid')
                _buildPaymentInfo(order),
              
              pw.Spacer(),
              
              // Footer
              _buildFooter(shop),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(Order order, Shop? shop) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              shop?.name ?? 'SpareLink Shop',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#10B981'),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Auto Parts Supplier',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColor.fromHex('#666666'),
              ),
            ),
            if (shop?.address != null) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                shop!.address!,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
            ],
            if (shop?.phone != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                shop!.phone!,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
            ],
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#333333'),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              order.invoiceNumber ?? order.displayId,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColor.fromHex('#666666'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceDetails(Order order) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F5F5F5'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Invoice Date', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#666666'))),
              pw.Text(
                _formatDate(order.createdAt),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Order ID', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#666666'))),
              pw.Text(
                order.displayId,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Status', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#666666'))),
              pw.Text(
                order.paymentStatus == 'paid' ? 'PAID' : 'PENDING',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: order.paymentStatus == 'paid' 
                      ? PdfColor.fromHex('#10B981') 
                      : PdfColor.fromHex('#F59E0B'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAddresses(Order order, Shop? shop) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BILL TO',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                order.customerName ?? 'Customer',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              if (order.customerPhone != null)
                pw.Text(order.customerPhone!, style: const pw.TextStyle(fontSize: 10)),
              if (order.customerEmail != null)
                pw.Text(order.customerEmail!, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SHIP TO',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                order.deliveryTo == DeliveryDestination.mechanic 
                    ? 'Mechanic Workshop' 
                    : 'Customer Address',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                order.deliveryAddress ?? 'Address on file',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (order.deliveryInstructions != null) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  'Note: ${order.deliveryInstructions}',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable(Order order, Offer? offer, double partPrice, double deliveryFee) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E5E5')),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5F5F5')),
          children: [
            _tableCell('Description', isHeader: true),
            _tableCell('Qty', isHeader: true, align: pw.TextAlign.center),
            _tableCell('Unit Price', isHeader: true, align: pw.TextAlign.right),
            _tableCell('Amount', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        // Part Row
        pw.TableRow(
          children: [
            _tableCell(order.partCategory ?? 'Auto Part'),
            _tableCell('1', align: pw.TextAlign.center),
            _tableCell('R ${partPrice.toStringAsFixed(2)}', align: pw.TextAlign.right),
            _tableCell('R ${partPrice.toStringAsFixed(2)}', align: pw.TextAlign.right),
          ],
        ),
        // Delivery Row
        pw.TableRow(
          children: [
            _tableCell('Delivery Fee'),
            _tableCell('1', align: pw.TextAlign.center),
            _tableCell('R ${deliveryFee.toStringAsFixed(2)}', align: pw.TextAlign.right),
            _tableCell('R ${deliveryFee.toStringAsFixed(2)}', align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  pw.Widget _tableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColor.fromHex('#666666') : PdfColor.fromHex('#333333'),
        ),
      ),
    );
  }

  pw.Widget _buildTotals(double subtotal, double vat, double total) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 200,
          child: pw.Column(
            children: [
              _totalRow('Subtotal', subtotal),
              _totalRow('VAT (15%)', vat),
              pw.Divider(color: PdfColor.fromHex('#333333'), thickness: 2),
              _totalRow('Total', total, isTotal: true),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow(String label, double amount, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 11,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            'R ${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 11,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isTotal ? PdfColor.fromHex('#10B981') : null,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPaymentInfo(Order order) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#ECFDF5'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor.fromHex('#10B981')),
      ),
      child: pw.Row(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Payment Received',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#166534'),
                ),
              ),
              if (order.paymentReference != null)
                pw.Text(
                  'Reference: ${order.paymentReference}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#15803D')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(Shop? shop) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColor.fromHex('#E5E5E5')),
        pw.SizedBox(height: 10),
        pw.Text(
          'Thank you for your business!',
          style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#666666')),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'For queries, contact us at ${shop?.email ?? 'support@sparelink.co.za'}',
          style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#999999')),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Download invoice to device
  Future<File> downloadInvoice(Order order) async {
    final pdfBytes = await generateInvoice(order);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/invoice_${order.displayId}.pdf');
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  /// Print or share invoice
  Future<void> printInvoice(Order order) async {
    final pdfBytes = await generateInvoice(order);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${order.displayId}',
    );
  }

  /// Share invoice
  Future<void> shareInvoice(Order order) async {
    final pdfBytes = await generateInvoice(order);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${order.displayId}.pdf',
    );
  }
}
