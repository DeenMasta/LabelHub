import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/features/imports/data/csv_import_parser.dart';

void main() {
  const parser = CsvImportParser();

  test('parses headers, quoted values, and skips blank rows', () {
    final document = parser.parse(
      'item_code,item_name,barcode\nITEM-1,"Blue, large",123\n\n',
    );

    expect(document.headers, <String>['item_code', 'item_name', 'barcode']);
    expect(document.rows, <List<String>>[
      <String>['ITEM-1', 'Blue, large', '123'],
    ]);
  });

  test('rejects duplicate headers', () {
    expect(
      () => parser.parse('item_code,item_code\nITEM-1,ITEM-1'),
      throwsFormatException,
    );
  });
}
