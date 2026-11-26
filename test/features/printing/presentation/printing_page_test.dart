import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/core/printing/printer_catalog.dart';
import 'package:labelhub/core/printing/tspl_label_command_encoder.dart';
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
    await printerProfiles.saveProfile(
      id: 'warehouse-zywell',
      name: 'Warehouse ZYWELL',
      address: 'AA:BB:CC:DD:EE:FF',
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
    expect(find.text('Choose labels to print'), findsOneWidget);
    expect(
      find.text('Set the quantity for each product you want to print.'),
      findsOneWidget,
    );
    expect(find.text('Print Configuration'), findsOneWidget);
    expect(find.text('Ready to print'), findsNothing);
    expect(find.text('Technical output details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends labels without calibrating media for every job', (
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
            printerCatalog: PrinterCatalog(bluetoothPrinter: printer),
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

    expect(printer.operations, <String>['connect', 'print']);
    expect(printer.lastRequest!.secondaryFieldIsPrice, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('passes the selected non-price field to the printer', (
    tester,
  ) async {
    final printer = _FakeTsplPrinter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PrintingPage(
            initialRecordIds: const <String>['record-1'],
            initialLayoutId: 'price-label-40x30',
            initialSecondaryFieldKey: 'item_name',
            printerCatalog: PrinterCatalog(bluetoothPrinter: printer),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Print 1 label');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(printer.lastRequest!.secondaryFieldIsPrice, isFalse);
    expect(printer.lastRequest!.labels.single.secondaryText, 'Blue T-Shirt');
  });

  testWidgets('sends the no-date price-label layout to the printer', (
    tester,
  ) async {
    await database.saveImportBatch(
      batchId: 'batch-ayam',
      templateId: 'system-product-v1',
      fileName: 'ayam.csv',
      totalRows: 1,
      validRows: 1,
      invalidRows: 0,
      records: const <DatabaseRecordInsert>[
        DatabaseRecordInsert(
          id: 'ayam',
          reference: 'Ayam',
          barcodeValue: '2000112005052',
          values: <String, String>{
            'item_name': 'Ayam',
            'price': '0.00',
            'barcode': '2000112005052',
          },
        ),
      ],
    );
    final printer = _FakeTsplPrinter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PrintingPage(
            initialRecordIds: const <String>['ayam'],
            initialLayoutId: 'price-label-40x30',
            printerCatalog: PrinterCatalog(bluetoothPrinter: printer),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Print 1 label');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    final request = printer.lastRequest!;
    expect(request.isPriceLabel, isTrue);
    expect(request.labels.single.expiryDate, isEmpty);
    expect(request.labels.single.receiveDate, isEmpty);
    final commands = String.fromCharCodes(
      const TsplLabelCommandEncoder().encode(request),
    );
    expect(commands, contains('TEXT 24,12,"5",0,1,1,"Ayam"'));
    expect(commands, contains('TEXT 48,64,"3",0,2,2,"RM 0.00"'));
  });

  testWidgets('calibrates media only when requested', (
    WidgetTester tester,
  ) async {
    final printer = _FakeTsplPrinter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PrintingPage(
            initialRecordIds: const <String>['record-1'],
            printerCatalog: PrinterCatalog(bluetoothPrinter: printer),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calibrate label media'));
    await tester.pumpAndSettle();

    expect(printer.operations, <String>['connect', 'calibrate']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends labels to the saved USB printer profile', (
    WidgetTester tester,
  ) async {
    final bluetoothPrinter = _FakeTsplPrinter();
    final usbPrinter = _FakeTsplPrinter();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final printerProfiles = PrinterProfileRepository(database);
    await printerProfiles.saveProfile(
      id: 'packing-usb',
      name: 'Packing station USB printer',
      address: '/dev/bus/usb/001/004',
      connectionType: PrinterConnectionType.usb,
    );
    await printerProfiles.setDefault('packing-usb');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PrintingPage(
            initialRecordIds: const <String>['record-1'],
            printerCatalog: PrinterCatalog(
              bluetoothPrinter: bluetoothPrinter,
              usbPrinter: usbPrinter,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final printButton = find.widgetWithText(FilledButton, 'Print 1 label');
    await tester.ensureVisible(printButton);
    await tester.tap(printButton);
    await tester.pumpAndSettle();

    expect(usbPrinter.operations, <String>['connect', 'print', 'disconnect']);
    expect(bluetoothPrinter.operations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses an incoming label quantity for the selected product', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PrintingPage(
            initialRecordCopies: <String, int>{'record-1': 3},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Print 3 labels'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeTsplPrinter implements LabelPrinter, TsplMediaCalibratingPrinter {
  final List<String> operations = <String>[];
  PrintRequest? lastRequest;

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
    lastRequest = request;
    return const PrintResult(succeeded: true);
  }
}
