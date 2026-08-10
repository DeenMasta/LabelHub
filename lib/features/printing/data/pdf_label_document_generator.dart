import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utilities/label_units.dart';
import '../../labels/data/barcode_preview_service.dart';
import '../../labels/domain/entities/barcode_request.dart';
import '../../labels/domain/entities/label_layout.dart';
import '../../records/domain/entities/catalogue_record.dart';
import '../../templates/data/builtin_templates.dart';
import '../../templates/domain/entities/import_template.dart';

/// Builds physically sized, one-label-per-page PDFs for the system printer.
class PdfLabelDocumentGenerator {
  const PdfLabelDocumentGenerator({
    BarcodePreviewService barcodePreviewService = const BarcodePreviewService(),
  }) : _barcodePreviewService = barcodePreviewService;

  final BarcodePreviewService _barcodePreviewService;

  Future<Uint8List> generate({
    required List<CatalogueRecord> records,
    required int copies,
    LabelLayout layout = productLabelLayout,
    String primaryFieldKey = 'item_name',
    String secondaryFieldKey = 'price',
  }) async {
    if (records.isEmpty) {
      throw const PdfLabelDocumentException('Select at least one record.');
    }
    if (copies < 1) {
      throw const PdfLabelDocumentException('Copies must be at least one.');
    }

    final document = pw.Document();
    final pageFormat = PdfPageFormat(
      LabelUnits.mmToPoints(layout.widthMm),
      LabelUnits.mmToPoints(layout.heightMm),
      marginAll: 0,
    );
    for (final record in records) {
      _validateBarcode(record, layout);
      for (var copy = 0; copy < copies; copy++) {
        document.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (_) => _buildLabel(
              record: record,
              layout: layout,
              primaryFieldKey: primaryFieldKey,
              secondaryFieldKey: secondaryFieldKey,
            ),
          ),
        );
      }
    }
    return document.save();
  }

  void _validateBarcode(CatalogueRecord record, LabelLayout layout) {
    final preview = _barcodePreviewService.create(
      BarcodeRequest(
        value: record.barcodeValue,
        format: productTemplate.barcodeFormat,
        widthMm: layout.barcodeWidthMm,
        heightMm: layout.barcodeHeightMm,
        showText: false,
      ),
    );
    if (!preview.isValid) {
      throw PdfLabelDocumentException(
        '${record.reference} cannot be printed: ${preview.errorMessage}',
      );
    }
  }

  pw.Widget _buildLabel({
    required CatalogueRecord record,
    required LabelLayout layout,
    required String primaryFieldKey,
    required String secondaryFieldKey,
  }) {
    final horizontalPadding = LabelUnits.mmToPoints(layout.horizontalPaddingMm);
    final verticalPadding = LabelUnits.mmToPoints(layout.verticalPaddingMm);
    final barcodeWidth = LabelUnits.mmToPoints(layout.barcodeWidthMm);
    final barcodeHeight = LabelUnits.mmToPoints(layout.barcodeHeightMm);
    final barcodeTextHeight = LabelUnits.mmToPoints(3);
    final pageHeight = LabelUnits.mmToPoints(layout.heightMm);
    final barcodeTop =
        pageHeight - verticalPadding - barcodeHeight - barcodeTextHeight;
    return pw.Stack(
      children: <pw.Widget>[
        pw.Positioned(
          top: verticalPadding,
          left: horizontalPadding,
          right: horizontalPadding,
          child: pw.Text(
            _valueFor(record, primaryFieldKey),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(fontSize: LabelUnits.mmToPoints(3.8)),
          ),
        ),
        pw.Positioned(
          top: verticalPadding + LabelUnits.mmToPoints(5),
          left: horizontalPadding,
          right: horizontalPadding,
          child: pw.Text(
            _valueFor(record, secondaryFieldKey),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(fontSize: LabelUnits.mmToPoints(2.6)),
          ),
        ),
        pw.Positioned(
          top: barcodeTop,
          left: horizontalPadding,
          child: pw.BarcodeWidget(
            barcode: _barcodeFor(productTemplate.barcodeFormat),
            data: record.barcodeValue,
            width: barcodeWidth,
            height: barcodeHeight,
            drawText: false,
          ),
        ),
        pw.Positioned(
          top: barcodeTop + barcodeHeight,
          left: horizontalPadding,
          child: pw.SizedBox(
            width: barcodeWidth,
            height: barcodeTextHeight,
            child: pw.Center(
              child: pw.Text(
                record.barcodeValue,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  fontSize: LabelUnits.mmToPoints(2),
                  letterSpacing: .5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _valueFor(CatalogueRecord record, String fieldKey) {
    final value = record.values[fieldKey]?.trim();
    return value == null || value.isEmpty ? '-' : value;
  }

  Barcode _barcodeFor(BarcodeFormat format) {
    return switch (format) {
      BarcodeFormat.code128 => Barcode.code128(),
      BarcodeFormat.code39 => Barcode.code39(),
      BarcodeFormat.ean13 => Barcode.ean13(),
      BarcodeFormat.qrCode => Barcode.qrCode(),
    };
  }
}

class PdfLabelDocumentException implements Exception {
  const PdfLabelDocumentException(this.message);

  final String message;

  @override
  String toString() => message;
}
