import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/features/printing/presentation/printing_page.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
    await database.upsertTemplate(
      id: 'system-product-v1',
      name: 'Product label',
      description: '',
      barcodeType: 'code128',
      barcodeFieldKey: 'barcode',
      isSystemTemplate: true,
    );
    await database.saveImportBatch(
      batchId: 'batch-1',
      templateId: 'system-product-v1',
      fileName: 'products.csv',
      totalRows: 1,
      validRows: 1,
      invalidRows: 0,
      records: const <DatabaseRecordInsert>[
        DatabaseRecordInsert(
          id: 'record-1',
          reference: 'ITEM-1001',
          barcodeValue: 'ITEM-1001',
          values: <String, String>{
            'item_name': 'Blue T-Shirt',
            'barcode': 'ITEM-1001',
            'price': '29.90',
          },
        ),
      ],
    );
  });

  tearDown(() => database.close());

  testWidgets('fits print controls into a compact phone layout', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PrintingPage(initialRecordIds: <String>['record-1']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Print labels'), findsAtLeastNWidgets(1));
    expect(find.text('Total labels'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
