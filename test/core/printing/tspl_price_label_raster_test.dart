import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/core/printing/tspl_label_command_encoder.dart';

void main() {
  testWidgets(
    'renders price-label name left and price centered as TSPL bitmaps',
    (tester) async {
      const request = PrintRequest(
        recordIds: <String>['ayam'],
        labels: <PrintLabelData>[
          PrintLabelData(
            primaryText: 'Ayam',
            secondaryText: '0.00',
            barcodeValue: '2000112005052',
            copies: 2,
          ),
        ],
        labelWidthMm: 40,
        labelHeightMm: 30,
        isPriceLabel: true,
      );
      final bytes = (await tester.runAsync(
        () => const TsplLabelCommandEncoder().encodeForPrinter(request),
      ))!;
      final wire = String.fromCharCodes(bytes);
      const nameHeader = 'BITMAP 0,12,40,48,0,';
      const priceHeader = 'BITMAP 0,64,40,48,0,';
      final nameStart = wire.indexOf(nameHeader) + nameHeader.length;
      final priceStart = wire.indexOf(priceHeader) + priceHeader.length;
      expect(nameStart, greaterThanOrEqualTo(nameHeader.length));
      expect(priceStart, greaterThan(nameStart + 40 * 48));
      expect(RegExp('BITMAP 0,12,40,48,0,').allMatches(wire), hasLength(2));
      expect(RegExp('BITMAP 0,64,40,48,0,').allMatches(wire), hasLength(2));
      expect(wire, contains('BARCODE 37,116,"128",52,0,0,2,2,"2000112005052"'));
      expect(wire, contains('PRINT 1,1\r\n'));

      final nameBounds = _blackBounds(bytes, nameStart);
      final priceBounds = _blackBounds(bytes, priceStart);
      expect(nameBounds.$1, inInclusiveRange(24, 30));
      expect((priceBounds.$1 + priceBounds.$2) / 2, closeTo(160, 5));
      expect(priceBounds.$2 - priceBounds.$1, greaterThan(50));
    },
  );

  testWidgets('prints a larger dated name and separates left-aligned dates', (
    tester,
  ) async {
    const request = PrintRequest(
      recordIds: <String>['chicken'],
      labels: <PrintLabelData>[
        PrintLabelData(
          primaryText: 'Chicken Chop',
          secondaryText: '25.54',
          barcodeValue: '8885020760019',
          copies: 1,
          expiryDate: '2027-12-31',
          receiveDate: '2026-11-26',
        ),
      ],
      labelWidthMm: 40,
      labelHeightMm: 30,
      isPriceLabel: true,
    );
    final bytes = (await tester.runAsync(
      () => const TsplLabelCommandEncoder().encodeForPrinter(request),
    ))!;
    final wire = String.fromCharCodes(bytes);
    expect(wire, contains('BITMAP 0,8,40,32,0,'));
    expect(wire, contains('BITMAP 0,44,40,40,0,'));
    expect(wire, contains('TEXT 82,130,"1",0,1,1,"8885020760019"'));
    expect(wire, contains('TEXT 24,158,"1",0,1,1,"EXP:2027-12-31"'));
    expect(wire, contains('TEXT 24,180,"1",0,1,1,"RCV:2026-11-26"'));
  });

  test('leaves product-label commands unchanged', () async {
    const request = PrintRequest(
      recordIds: <String>['a'],
      labels: <PrintLabelData>[
        PrintLabelData(
          primaryText: 'Milk',
          secondaryText: '10',
          barcodeValue: '123456',
          copies: 1,
        ),
      ],
      labelWidthMm: 40,
      labelHeightMm: 30,
    );
    const encoder = TsplLabelCommandEncoder();
    expect(await encoder.encodeForPrinter(request), encoder.encode(request));
  });
}

(int, int) _blackBounds(Uint8List bytes, int start) {
  var left = 320;
  var right = -1;
  for (var y = 0; y < 48; y++) {
    for (var x = 0; x < 320; x++) {
      if (bytes[start + y * 40 + x ~/ 8] & (128 >> (x % 8)) == 0) {
        if (x < left) left = x;
        if (x > right) right = x;
      }
    }
  }
  return (left, right);
}
