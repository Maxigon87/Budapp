import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/company_provider.dart';
import '../providers/quotes_provider.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<Uint8List> generateQuotePdf({
    required CompanyProvider company,
    required Quote quote,
  }) async {
    final pdf = pw.Document();
    
    // Load Logo if available
    pw.ImageProvider? logoImage;
    if (company.logoPath != null && company.logoPath!.isNotEmpty) {
      try {
        final file = File(company.logoPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (e) {
        // Safe fallback if logo cannot be loaded
        print("Error loading logo for PDF: $e");
      }
    }
    
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company info
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 60,
                            height: 60,
                            margin: const pw.EdgeInsets.only(right: 12),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                company.name.isNotEmpty ? company.name : "Servicios Técnicos",
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.teal900,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              if (company.address.isNotEmpty)
                                pw.Text(company.address, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                              if (company.phone.isNotEmpty)
                                pw.Text("Tel: ${company.phone}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                              if (company.email.isNotEmpty)
                                pw.Text("Email: ${company.email}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                              if (company.website.isNotEmpty)
                                pw.Text("Web: ${company.website}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quote identification
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "PRESUPUESTO",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        "N°: ${quote.number}",
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        "Fecha: ${dateFormat.format(quote.date)}",
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.teal100, thickness: 1),
              pw.SizedBox(height: 15),

              // Client details Card
              pw.Container(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                padding: const pw.EdgeInsets.all(12),
                width: double.infinity,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "CLIENTE",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Nombre: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey800),
                        ),
                        pw.Text(quote.clientName, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
                      ],
                    ),
                    if (quote.clientPhone.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text(
                            "Teléfono: ",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey800),
                          ),
                          pw.Text(quote.clientPhone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
                        ],
                      ),
                    ],
                    if (quote.clientAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text(
                            "Dirección: ",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey800),
                          ),
                          pw.Text(quote.clientAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 25),

              // Services Table
              pw.Text(
                "DETALLE DE CONCEPTOS / SERVICIOS",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal800,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.teal300, width: 1.5),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.5),
                  1: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.teal,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        child: pw.Text(
                          "Servicio",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            "Precio",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Table Rows
                  ...quote.items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          child: pw.Text(item.name, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(
                              currencyFormat.format(item.price),
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 15),

              // Total Row
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        "TOTAL: ",
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        currencyFormat.format(quote.total),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // Observations
              if (quote.observations.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Observaciones:",
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        quote.observations,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Footer
              pw.Center(
                child: pw.Text(
                  "Este presupuesto tiene validez por 15 días a partir de la fecha de emisión.",
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  "¡Gracias por confiar en nosotros!",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
