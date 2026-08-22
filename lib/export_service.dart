import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

abstract interface class InvoicePrinter {
  Future<void> printPdf(List<int> pdfBytes);
}

class PrintingInvoicePrinter implements InvoicePrinter {
  const PrintingInvoicePrinter();

  @override
  Future<void> printPdf(List<int> pdfBytes) {
    return Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(pdfBytes),
    );
  }
}

abstract interface class FileWriter {
  Future<File> write(String fileName, List<int> bytes);
}

class LocalFileWriter implements FileWriter {
  const LocalFileWriter();

  @override
  Future<File> write(String fileName, List<int> bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

class ExportService {
  const ExportService({
    InvoicePrinter printer = const PrintingInvoicePrinter(),
    FileWriter fileWriter = const LocalFileWriter(),
  })  : _printer = printer,
        _fileWriter = fileWriter;

  final InvoicePrinter _printer;
  final FileWriter _fileWriter;

  Future<List<int>> buildInvoicePdf(
    List<Map<String, dynamic>> transactions,
  ) async {
    final document = pw.Document();
    final total = transactions.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'Smart Accountant - فاتورة العمليات',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: const ['النوع', 'الوصف', 'المبلغ', 'التاريخ'],
                data: transactions
                    .map((row) => [
                          row['type']?.toString() ?? '',
                          row['description']?.toString() ?? '',
                          '${row['amount'] ?? 0} ر.ي',
                          row['date']?.toString() ?? '',
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 18),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'الإجمالي: ${total.toStringAsFixed(0)} ر.ي',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final bytes = await document.save();
    if (bytes.isEmpty) {
      throw StateError('تعذر إنشاء مستند PDF فارغ');
    }
    return bytes;
  }

  Future<void> printInvoice(
    List<Map<String, dynamic>> transactions,
  ) async {
    final bytes = await buildInvoicePdf(transactions);
    await _printer.printPdf(bytes);
  }

  Future<File> exportToExcel(
    List<Map<String, dynamic>> transactions,
  ) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['العمليات'];
    sheet.appendRow([
      TextCellValue('النوع'),
      TextCellValue('الوصف'),
      TextCellValue('المبلغ'),
      TextCellValue('التاريخ'),
    ]);

    for (final row in transactions) {
      sheet.appendRow([
        TextCellValue(row['type']?.toString() ?? ''),
        TextCellValue(row['description']?.toString() ?? ''),
        DoubleCellValue((row['amount'] as num?)?.toDouble() ?? 0),
        TextCellValue(row['date']?.toString() ?? ''),
      ]);
    }

    final bytes = workbook.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('تعذر إنشاء ملف Excel');
    }

    return _fileWriter.write(
      'smart_accountant_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      bytes,
    );
  }
}
