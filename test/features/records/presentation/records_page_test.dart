import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/core/printing/printer_catalog.dart';
import 'package:labelhub/features/printing/data/printer_profile_repository.dart';
import 'package:labelhub/features/records/presentation/record_details_page.dart';
import 'package:labelhub/features/records/presentation/records_page.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
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
          reference: 'ITEM-002',
          barcodeValue: 'ABC-001',
          values: <String, String>{
            'item_code': 'ITEM-002',
            'item_name': 'Zebra T-Shirt',
            'barcode': 'ABC-001',
            'category': 'Apparel',
            'price': 'RM 29.90',
          },
        ),
        DatabaseRecordInsert(
          id: 'record-2',
          reference: 'ITEM-001',
          barcodeValue: 'ABC-002',
          values: <String, String>{
            'item_code': 'ITEM-001',
            'item_name': 'Blue Hoodie',
            'barcode': 'ABC-002',
            'category': ' apparel ',
          },
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
  });

  tearDown(() => database.close());

  testWidgets('filters and sorts products without a catalogue overview', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RecordsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catalogue overview'), findsNothing);
    expect(find.byKey(const Key('records-import-button')), findsOneWidget);
    expect(find.text('Find, filter, and sort'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Blue Hoodie'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Blue Hoodie'), findsOneWidget);
    expect(find.text('Category: apparel'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'hoodie');
    await tester.pumpAndSettle();
    expect(find.text('Blue Hoodie'), findsOneWidget);
    expect(find.text('Zebra T-Shirt'), findsNothing);

    await tester.enterText(find.byType(EditableText), '');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('record-category-filter')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('record-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('apparel').last);
    await tester.pumpAndSettle();
    expect(find.text('Blue Hoodie'), findsOneWidget);
    expect(find.text('Zebra T-Shirt'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('record-sort-selector')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('record-sort-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name (A-Z)').last);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Blue Hoodie')).dy,
      lessThan(tester.getTopLeft(find.text('Zebra T-Shirt')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('prints the viewed record directly from its detail page', (
    WidgetTester tester,
  ) async {
    final printer = _FakeLabelPrinter();
    final router = GoRouter(
      initialLocation: '/records/record-2',
      routes: <RouteBase>[
        GoRoute(
          path: '/records/:recordId',
          builder: (_, GoRouterState state) => Scaffold(
            body: RecordDetailsPage(
              recordId: state.pathParameters['recordId']!,
              printerCatalog: PrinterCatalog(bluetoothPrinter: printer),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record-print-button')));
    await tester.pumpAndSettle();
    expect(find.text('Label quantity'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('print-quantity-input')),
      '100',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Print labels'));
    await tester.pumpAndSettle();

    expect(printer.operations, <String>['connect', 'print', 'disconnect']);
    expect(printer.request!.recordIds, <String>['record-2']);
    expect(printer.request!.labels.single.copies, 100);
    expect(find.byType(RecordDetailsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens imports from the floating import action', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/records',
      routes: <RouteBase>[
        GoRoute(path: '/records', builder: (_, _) => const RecordsPage()),
        GoRoute(
          path: '/imports',
          builder: (_, _) => const Scaffold(body: Text('Import page opened')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('records-import-button')));
    await tester.pumpAndSettle();

    expect(find.text('Import page opened'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeLabelPrinter implements LabelPrinter {
  final List<String> operations = <String>[];
  PrintRequest? request;

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
    this.request = request;
    return const PrintResult(succeeded: true);
  }
}
