import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/core/printing/printer_catalog.dart';
import 'package:labelhub/features/printing/data/printer_profile_repository.dart';
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
    final printerProfiles = PrinterProfileRepository(database);
    await printerProfiles.saveNetwork(
      id: 'warehouse-zywell',
      name: 'Warehouse ZYWELL',
      host: '192.168.1.30',
      port: 9100,
    );
    await printerProfiles.setDefault('warehouse-zywell');
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
    expect(find.text('Copies for each product'), findsOneWidget);
    expect(
      find.text('Each selected product prints this many labels.'),
      findsOneWidget,
    );
    expect(find.text('Ready to print'), findsNothing);
    expect(find.text('Technical output details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calibrates a TSPL printer before sending labels', (
    WidgetTester tester,
  ) async {
    final printer = _FakeTsplPrinter();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PrintingPage(
            initialRecordIds: const <String>['record-1'],
            printerCatalog: PrinterCatalog(networkPrinter: printer),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final printButton = find.widgetWithText(FilledButton, 'Print 1 label');
    await tester.ensureVisible(printButton);
    await tester.pumpAndSettle();
    await tester.tap(printButton);
    await tester.pumpAndSettle();

    expect(printer.operations, <String>[
      'connect',
      'calibrate',
      'print',
      'disconnect',
    ]);
    expect(tester.takeException(), isNull);
  });
}

class _FakeTsplPrinter implements LabelPrinter, TsplMediaCalibratingPrinter {
  final List<String> operations = <String>[];

  @override
  Future<PrintResult> calibrateTsplMedia({
    required double widthMm,
    required double heightMm,
  }) async {
    operations.add('calibrate');
    return const PrintResult(succeeded: true);
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    operations.add('connect');
  }

  @override
  Future<List<PrinterDevice>> discover() async => const <PrinterDevice>[];

  @override
  Future<void> disconnect() async {
    operations.add('disconnect');
  }

  @override
  Future<PrintResult> printLabels(PrintRequest request) async {
    operations.add('print');
    return const PrintResult(succeeded: true);
  }
}
