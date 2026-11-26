import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/core/printing/tspl_label_command_encoder.dart';

void main() {
  const encoder = TsplLabelCommandEncoder();

  PrintRequest request({
    String barcodeValue = 'ITEM-1001',
    String primaryText = 'Blue T-Shirt',
    String expiryDate = '',
    String receiveDate = '',
    double widthMm = 40,
  }) => PrintRequest(
    recordIds: const <String>['record-1'],
    labels: <PrintLabelData>[
      PrintLabelData(
        primaryText: primaryText,
        secondaryText: '29.90',
        barcodeValue: barcodeValue,
        copies: 1,
        expiryDate: expiryDate,
        receiveDate: receiveDate,
      ),
    ],
    labelWidthMm: widthMm,
    labelHeightMm: 30,
  );

  test('encodes a 40 by 30 mm label with native text and barcode commands', () {
    final commands = String.fromCharCodes(encoder.encode(request()));

    expect(commands, contains('SIZE 40 mm,30 mm'));
    expect(commands, isNot(contains('GAP ')));
    expect(commands, contains('TEXT 24,12,"3",0,1,1,"Blue T-Shirt"'));
    expect(commands, contains('TEXT 24,40,"2",0,1,1,"29.90"'));
    expect(commands, contains('BARCODE 26,64,"128",52,0,0,2,2,"ITEM-1001"'));
    expect(commands, contains('TEXT 106,118,"1",0,1,1,"ITEM-1001"'));
    expect(commands, endsWith('PRINT 1,1\r\n'));
    expect(commands, isNot(contains('BITMAP')));
  });

  test('wraps long names and rejects names that cannot fit', () {
    final short = String.fromCharCodes(
      encoder.encode(request(primaryText: 'Milk')),
    );
    expect(short, contains('TEXT 24,12,"4",0,1,1,"Milk"'));
    final long = String.fromCharCodes(
      encoder.encode(
        request(primaryText: 'Delicious blueberry muffin with chocolate chips'),
      ),
    );
    expect(long, contains('"Delicious blueberry"'));
    expect(long, contains('"muffin with chocolate"'));
    expect(long, contains('"chips"'));
    expect(
      () => encoder.encode(request(primaryText: 'x' * 100)),
      throwsFormatException,
    );
  });

  test('rejects barcode values that cannot form a TSPL command', () {
    expect(
      () => encoder.encode(request(barcodeValue: 'ITEM\n1001')),
      throwsFormatException,
    );
  });

  test(
    'fits and centers barcodes on a narrow label or rejects oversize values',
    () {
      final commands = String.fromCharCodes(
        encoder.encode(request(widthMm: 30)),
      );
      expect(commands, contains('BARCODE 53,64,"128",52,0,0,1,1,"ITEM-1001"'));
      expect(
        () => encoder.encode(request(widthMm: 30, barcodeValue: 'A' * 30)),
        throwsFormatException,
      );
      expect(
        () => encoder.encode(request(barcodeValue: 'abcé')),
        throwsFormatException,
      );
    },
  );

  test('uses wider bars for a 13-digit numeric barcode when it fits', () {
    final commands = String.fromCharCodes(
      encoder.encode(request(barcodeValue: '2000112005052')),
    );
    expect(
      commands,
      contains('BARCODE 37,64,"128",52,0,0,2,2,"2000112005052"'),
    );
    expect(commands, contains('TEXT 82,118,"1",0,1,1,"2000112005052"'));
  });

  test('omits barcode commands when the barcode is blank', () {
    final commands = String.fromCharCodes(
      encoder.encode(request(barcodeValue: '')),
    );

    expect(commands, isNot(contains('BARCODE')));
  });

  test('encodes an enlarged price label without barcode commands', () {
    final commands = String.fromCharCodes(
      encoder.encode(
        PrintRequest(
          recordIds: const <String>['record-1'],
          labels: const <PrintLabelData>[
            PrintLabelData(
              primaryText: 'Blue T-Shirt',
              secondaryText: 'RM 29.90',
              barcodeValue: 'ITEM-1001',
              copies: 1,
              expiryDate: '2027-12-31',
              receiveDate: '2026-11-19',
            ),
          ],
          labelWidthMm: 40,
          labelHeightMm: 30,
          isPriceLabel: true,
        ),
      ),
    );

    expect(commands, contains('TEXT 24,84,"2",0,2,2,"RM 29.90"'));
    expect(commands, contains('TEXT 24,160,"1",0,1,1,"EXP:2027-12-31"'));
    expect(commands, contains('TEXT 24,176,"1",0,1,1,"RCV:2026-11-19"'));
    expect(commands, isNot(contains('BARCODE')));
    expect(commands, isNot(contains('ITEM-1001')));
  });

  test('keeps price-label dates below a two-line product name', () {
    final commands = String.fromCharCodes(
      encoder.encode(
        PrintRequest(
          recordIds: const <String>['record-1'],
          labels: const <PrintLabelData>[
            PrintLabelData(
              primaryText: 'Delicious Blueberry Muffin',
              secondaryText: 'RM 29.90',
              barcodeValue: '',
              copies: 1,
              expiryDate: '2027-12-31',
              receiveDate: '2026-11-19',
            ),
          ],
          labelWidthMm: 40,
          labelHeightMm: 30,
          isPriceLabel: true,
        ),
      ),
    );

    expect(commands, contains('TEXT 24,100,"2",0,2,2,"RM 29.90"'));
    expect(commands, contains('TEXT 24,168,"1",0,1,1,"EXP:2027-12-31"'));
    expect(commands, contains('TEXT 24,184,"1",0,1,1,"RCV:2026-11-19"'));
  });

  test('prints receive date below expiry below the barcode', () {
    final commands = String.fromCharCodes(
      encoder.encode(
        request(expiryDate: '2027-12-31', receiveDate: '2026-11-19'),
      ),
    );

    expect(commands, contains('TEXT 76,144,"1",0,1,1,"EXP:2027-12-31"'));
    expect(commands, contains('TEXT 76,164,"1",0,1,1,"RCV:2026-11-19"'));
  });

  test('keeps stacked dates inside a narrow label', () {
    final commands = String.fromCharCodes(
      encoder.encode(
        PrintRequest(
          recordIds: const <String>['record-1'],
          labels: const <PrintLabelData>[
            PrintLabelData(
              primaryText: 'Delicious Blueberry Muffin',
              secondaryText: '29.90',
              barcodeValue: 'ITEM-1001',
              copies: 1,
              expiryDate: '2027-12-31',
              receiveDate: '2026-11-19',
            ),
          ],
          labelWidthMm: 30,
          labelHeightMm: 40,
        ),
      ),
    );

    expect(commands, contains('TEXT 36,166,"1",0,1,1,"EXP:2027-12-31"'));
    expect(commands, contains('TEXT 36,186,"1",0,1,1,"RCV:2026-11-19"'));
  });

  test('reserves room for both dates after a three-line product name', () {
    final commands = String.fromCharCodes(
      encoder.encode(
        request(
          primaryText: 'Delicious blueberry muffin with chocolate chips',
          expiryDate: '2027-12-31',
          receiveDate: '2026-11-19',
        ),
      ),
    );
    expect(commands, contains('TEXT 24,56,"2",0,1,1,"chips"'));
    expect(commands, contains('TEXT 24,84,"2",0,1,1,"29.90"'));
    expect(commands, contains('BARCODE 26,108,"128",52,0,0,2,2,"ITEM-1001"'));
    expect(commands, contains('TEXT 76,188,"1",0,1,1,"EXP:2027-12-31"'));
    expect(commands, contains('TEXT 76,208,"1",0,1,1,"RCV:2026-11-19"'));
  });

  test('uses the same single-label commands for each requested copy', () {
    final commands = String.fromCharCodes(
      encoder.encode(
        PrintRequest(
          recordIds: const <String>['record-1'],
          labels: const <PrintLabelData>[
            PrintLabelData(
              primaryText: 'Blue T-Shirt',
              secondaryText: '29.90',
              barcodeValue: 'ITEM-1001',
              copies: 50,
            ),
          ],
          labelWidthMm: 40,
          labelHeightMm: 30,
        ),
      ),
    );

    expect(commands, endsWith('PRINT 1,1\r\n'));
    expect(RegExp(r'PRINT 1,1').allMatches(commands), hasLength(50));
    expect(RegExp(r'CLS').allMatches(commands), hasLength(50));
    final blocks = commands.split('PRINT 1,1\r\n');
    expect(blocks.take(50).toSet(), hasLength(1));
  });

  test('prints multiple products and copies without extra feed commands', () {
    final commands = String.fromCharCodes(
      encoder.encode(
        const PrintRequest(
          recordIds: <String>['a', 'b'],
          labels: <PrintLabelData>[
            PrintLabelData(
              primaryText: 'Milk',
              secondaryText: '10',
              barcodeValue: '123456',
              copies: 2,
            ),
            PrintLabelData(
              primaryText: 'Tea',
              secondaryText: '5',
              barcodeValue: '654321',
              copies: 3,
            ),
          ],
          labelWidthMm: 40,
          labelHeightMm: 30,
        ),
      ),
    );
    expect(
      RegExp(r'^PRINT 1,1\r$', multiLine: true).allMatches(commands),
      hasLength(5),
    );
    expect(commands, isNot(contains('FEED')));
    expect(commands, isNot(contains('GAPDETECT')));
    expect(commands, isNot(contains('GAP ')));
    expect(RegExp('"Milk"').allMatches(commands), hasLength(2));
    expect(RegExp('"Tea"').allMatches(commands), hasLength(3));
  });

  test('prints every requested price-label copy', () {
    final commands = String.fromCharCodes(
      encoder.encode(
        const PrintRequest(
          recordIds: <String>['a'],
          labels: <PrintLabelData>[
            PrintLabelData(
              primaryText: 'Milk',
              secondaryText: '10',
              barcodeValue: '',
              copies: 2,
            ),
          ],
          labelWidthMm: 40,
          labelHeightMm: 30,
          isPriceLabel: true,
        ),
      ),
    );
    expect(RegExp('PRINT 1,1').allMatches(commands), hasLength(2));
    expect(RegExp('"Milk"').allMatches(commands), hasLength(2));
  });
}
