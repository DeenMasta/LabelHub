import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/validation/import_validation_service.dart';
import 'package:labelhub/features/templates/data/builtin_templates.dart';

void main() {
  const validator = ImportValidationService();

  test('accepts a complete, unique product row', () {
    final result = validator.validate(
      template: productTemplate,
      headers: const <String>['item_code', 'item_name', 'barcode', 'price'],
      rows: const <List<String>>[
        <String>['ITEM-1001', 'Blue T-Shirt', '9551234567890', '29.90'],
      ],
      columnMapping: const <String, String?>{
        'item_code': 'item_code',
        'item_name': 'item_name',
        'barcode': 'barcode',
        'price': 'price',
      },
      existingBarcodeValues: const <String>{},
    );

    expect(result.validRowCount, 1);
    expect(result.invalidRowCount, 0);
  });

  test('reports required fields, invalid numbers, and duplicate barcodes', () {
    final result = validator.validate(
      template: productTemplate.withRequiredFieldKeys(<String>{
        'item_code',
        'item_name',
        'barcode',
      }),
      headers: const <String>['item_code', 'item_name', 'barcode', 'price'],
      rows: const <List<String>>[
        <String>['', 'Blue T-Shirt', '9551234567890', 'not-a-price'],
        <String>['ITEM-1002', 'Green T-Shirt', '9551234567890', '12.00'],
      ],
      columnMapping: const <String, String?>{
        'item_code': 'item_code',
        'item_name': 'item_name',
        'barcode': 'barcode',
        'price': 'price',
      },
      existingBarcodeValues: const <String>{},
    );

    expect(result.validRowCount, 0);
    expect(
      result.rows.first.issues.map((issue) => issue.message),
      contains('SKU is required.'),
    );

    expect(
      result.rows.last.issues.single.message,
      'Barcode already exists or is duplicated in this file.',
    );
  });

  test('allows an unrequired product code to be blank', () {
    final result = validator.validate(
      template: productTemplate,
      headers: const <String>['item_code', 'item_name', 'barcode'],
      rows: const <List<String>>[
        <String>['', 'Blue T-Shirt', 'ITEM-1001'],
      ],
      columnMapping: const <String, String?>{
        'item_code': 'item_code',
        'item_name': 'item_name',
        'barcode': 'barcode',
      },
      existingBarcodeValues: const <String>{},
    );

    expect(result.validRowCount, 1);
  });

  test('allows a product row without a barcode', () {
    final result = validator.validate(
      template: productTemplate,
      headers: const <String>['item_code', 'item_name', 'barcode'],
      rows: const <List<String>>[
        <String>['ITEM-1001', 'Blue T-Shirt', ''],
      ],
      columnMapping: const <String, String?>{
        'item_code': 'item_code',
        'item_name': 'item_name',
        'barcode': 'barcode',
      },
      existingBarcodeValues: const <String>{},
    );

    expect(result.validRowCount, 1);
  });

  test('accepts optional ISO dates and rejects invalid dates', () {
    final result = validator.validate(
      template: productTemplate,
      headers: const <String>[
        'item_code',
        'item_name',
        'barcode',
        'expiry_date',
        'receive_date',
      ],
      rows: const <List<String>>[
        <String>[
          'ITEM-1001',
          'Blue T-Shirt',
          'ITEM-1001',
          '2027-12-31',
          '2026-11-19',
        ],
        <String>[
          'ITEM-1002',
          'Green T-Shirt',
          'ITEM-1002',
          '31/12/2027',
          '',
        ],
      ],
      columnMapping: const <String, String?>{
        'item_code': 'item_code',
        'item_name': 'item_name',
        'barcode': 'barcode',
        'expiry_date': 'expiry_date',
        'receive_date': 'receive_date',
      },
      existingBarcodeValues: const <String>{},
    );

    expect(result.validRowCount, 1);
    expect(
      result.rows.last.issues.single.message,
      'Expiry date has an invalid date value.',
    );
  });
}
