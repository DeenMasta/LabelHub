import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/core/printing/tspl_label_command_encoder.dart';

void main() {
  const encoder = TsplLabelCommandEncoder();

  PrintRequest request({String barcodeValue = 'ITEM-1001'}) => PrintRequest(
    recordIds: const <String>['record-1'],
    labels: <PrintLabelData>[
      PrintLabelData(
        primaryText: 'Blue T-Shirt',
        secondaryText: '29.90',
        barcodeValue: barcodeValue,
        copies: 1,
      ),
    ],
    labelWidthMm: 40,
    labelHeightMm: 30,
  );

  test('encodes a 40 by 30 mm label with native text and barcode commands', () {
    final commands = String.fromCharCodes(encoder.encode(request()));

    expect(commands, contains('SIZE 40 mm,30 mm'));
    expect(commands, contains('GAP 2 mm,0 mm'));
    expect(commands, contains('TEXT 24,20,"3",0,1,1,"Blue T-Shirt"'));
    expect(commands, contains('BARCODE 24,92,"128",76,0,0,2,2,"ITEM-1001"'));
    expect(commands, endsWith('PRINT 1,1\r\n'));
    expect(commands, isNot(contains('BITMAP')));
  });

  test('rejects barcode values that cannot form a TSPL command', () {
    expect(
      () => encoder.encode(request(barcodeValue: 'ITEM\n1001')),
      throwsFormatException,
    );
  });
}
