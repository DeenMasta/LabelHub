import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/features/labels/presentation/labels_page.dart';

void main() {
  testWidgets('shows a clear label preview before printing', (
    WidgetTester tester,
  ) async {
    final database = await AppDatabase.openForTesting(NativeDatabase.memory());
    addTearDown(database.close);
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
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: LabelsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Continue to print 1 label'),
      200,
    );
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Continue to print 1 label'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Label content'), 200);
    expect(find.text('Label content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
