import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/features/records/data/record_repository.dart';

void main() {
  late AppDatabase database;
  late RecordRepository repository;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
    repository = RecordRepository(database);
    await database.upsertTemplate(
      id: 'product-v1',
      name: 'Product',
      description: '',
      barcodeType: 'code128',
      barcodeFieldKey: 'barcode',
      isSystemTemplate: true,
    );
    await database.saveImportBatch(
      batchId: 'batch-1',
      templateId: 'product-v1',
      fileName: 'products.csv',
      totalRows: 2,
      validRows: 2,
      invalidRows: 0,
      records: const <DatabaseRecordInsert>[
        DatabaseRecordInsert(
          id: 'record-1',
          reference: 'ITEM-001',
          barcodeValue: 'ABC-001',
          values: <String, String>{
            'item_code': 'ITEM-001',
            'item_name': 'Blue T-Shirt',
            'barcode': 'ABC-001',
          },
        ),
        DatabaseRecordInsert(
          id: 'record-2',
          reference: 'ITEM-002',
          barcodeValue: 'ABC-001',
          values: <String, String>{
            'item_code': 'ITEM-002',
            'item_name': 'Blue Hoodie',
            'barcode': 'ABC-001',
          },
        ),
      ],
    );
  });

  tearDown(() => database.close());

  test(
    'lists records and identifies another active record with the same barcode',
    () async {
      final records = await repository.list();

      expect(records, hasLength(2));
      expect(records.first.values['item_name'], isNotEmpty);
      expect(await repository.hasDuplicateBarcode(records.first), isTrue);
    },
  );

  test('saves edits, archives, and deletes a record', () async {
    final record = (await repository.list()).first;
    final updated = record.copyWith(
      reference: 'ITEM-009',
      barcodeValue: 'ABC-009',
      values: <String, String>{
        ...record.values,
        'item_code': 'ITEM-009',
        'barcode': 'ABC-009',
      },
    );

    await repository.save(updated);
    expect((await repository.getById(record.id))!.reference, 'ITEM-009');
    expect(await repository.hasDuplicateBarcode(updated), isFalse);

    await repository.archive(updated, archived: true);
    expect((await repository.getById(record.id))!.isArchived, isTrue);

    await repository.delete(updated);
    expect(await repository.getById(record.id), isNull);
  });
}
