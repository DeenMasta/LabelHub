import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/features/imports/data/import_parser.dart';

void main() {
  const parser = ImportParser();

  test('CSV: parses headers, quoted values, and skips blank rows', () {
    final document = parser.parseCsv(
      'item_code,item_name,barcode\nITEM-1,"Blue, large",123\n\n',
    );

    expect(document.headers, <String>['item_code', 'item_name', 'barcode']);
    expect(document.rows, <List<String>>[
      <String>['ITEM-1', 'Blue, large', '123'],
    ]);
  });

  test('CSV: rejects duplicate headers', () {
    expect(
      () => parser.parseCsv('item_code,item_code\nITEM-1,ITEM-1'),
      throwsFormatException,
    );
  });
}
