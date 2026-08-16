import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/features/dashboard/presentation/dashboard_page.dart';
import 'package:labelhub/features/printing/data/printer_profile_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('shows only current catalogue and printer details', (
    WidgetTester tester,
  ) async {
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
          reference: 'TSHIRT-001',
          barcodeValue: 'ABC-001',
          values: <String, String>{'item_name': 'Zebra T-Shirt'},
        ),
        DatabaseRecordInsert(
          id: 'record-2',
          reference: 'HOODIE-001',
          barcodeValue: 'ABC-002',
          values: <String, String>{'item_name': 'Blue Hoodie'},
        ),
      ],
    );
    final printerProfiles = PrinterProfileRepository(database);
    await printerProfiles.saveProfile(
      id: 'warehouse-zywell',
      name: 'Warehouse ZYWELL',
      address: 'AA:BB:CC:DD:EE:FF',
    );
    await printerProfiles.setDefault('warehouse-zywell');
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardHarness(database));
    await tester.pumpAndSettle();

    expect(find.text('Label operations'), findsOneWidget);
    expect(find.text('Prepare labels'), findsOneWidget);
    expect(find.text('2 products ready to label'), findsOneWidget);
    expect(find.text('Warehouse ZYWELL'), findsOneWidget);
    expect(find.text('Zebra T-Shirt'), findsOneWidget);
    expect(find.text('Blue Hoodie'), findsOneWidget);
    expect(find.text('Labels Printed per Day'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guides an empty workspace to import products', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_dashboardHarness(database));
    await tester.pumpAndSettle();

    expect(find.text('Import products'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
    expect(find.text('Recently updated'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _dashboardHarness(AppDatabase database) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((Ref ref) async => database)],
    child: MaterialApp(theme: AppTheme.light, home: const DashboardPage()),
  );
}
