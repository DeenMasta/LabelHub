import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/features/labels/data/barcode_preview_service.dart';
import 'package:labelhub/features/labels/domain/entities/barcode_request.dart';
import 'package:labelhub/features/templates/domain/entities/import_template.dart';

void main() {
  const service = BarcodePreviewService();

  test('creates physical draw marks for a valid Code 128 barcode', () {
    final preview = service.create(
      const BarcodeRequest(
        value: 'ITEM-1001',
        format: BarcodeFormat.code128,
        widthMm: 52,
        heightMm: 15,
        showText: false,
      ),
    );

    expect(preview.isValid, isTrue);
    expect(preview.widthMm, 52);
    expect(preview.heightMm, 15);
    expect(preview.marks, isNotEmpty);
  });

  test('surfaces invalid EAN-13 source data instead of rendering it', () {
    final preview = service.create(
      const BarcodeRequest(
        value: '1234567890123',
        format: BarcodeFormat.ean13,
        widthMm: 52,
        heightMm: 15,
        showText: false,
      ),
    );

    expect(preview.isValid, isFalse);
    expect(preview.errorMessage, isNotEmpty);
    expect(preview.marks, isEmpty);
  });
}
