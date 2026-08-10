import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/features/printing/data/pdf_label_document_generator.dart';
import 'package:labelhub/features/records/domain/entities/catalogue_record.dart';

void main() {
  const generator = PdfLabelDocumentGenerator();
  final record = CatalogueRecord(
    id: 'record-1',
    templateId: 'system-product-v1',
    reference: 'ITEM-1001',
    barcodeValue: 'ITEM-1001',
    values: const <String, String>{
      'item_name': 'Blue T-Shirt',
      'price': '29.90',
    },
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    isArchived: false,
  );

  test('generates a PDF for each selected record copy', () async {
    final pdf = await generator.generate(
      records: <CatalogueRecord>[record],
      copies: 2,
    );

    expect(pdf, isNotEmpty);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });

  test('rejects invalid barcode data before generating a PDF', () async {
    final invalidRecord = record.copyWith(barcodeValue: '');

    await expectLater(
      generator.generate(records: <CatalogueRecord>[invalidRecord], copies: 1),
      throwsA(isA<PdfLabelDocumentException>()),
    );
  });
}
