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
import 'package:labelhub/features/printing/presentation/printer_settings_page.dart';

void main() {
  testWidgets('fits printer settings into a compact phone layout', (
    WidgetTester tester,
  ) async {
    final database = await AppDatabase.openForTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PrinterSettingsPage(
            printerCatalog: PrinterCatalog(
              bluetoothPrinter: _FakeBluetoothPrinter(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Printer settings'), findsOneWidget);
    await tester.tap(find.text('Find paired printers'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pocket label printer — barcode labels (TSPL)'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves a network printer profile from settings', (
    WidgetTester tester,
  ) async {
    final database = await AppDatabase.openForTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PrinterSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add network printer'));
    await tester.pumpAndSettle();
    expect(find.text('TSPL'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Warehouse Zebra');
    await tester.enterText(find.byType(TextField).at(1), 'printer.local');
    await tester.enterText(find.byType(TextField).at(2), '9100');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    final profiles = await PrinterProfileRepository(database).list();
    expect(profiles, hasLength(1));
    expect(profiles.single.name, 'Warehouse Zebra');
    expect(tester.takeException(), isNull);
  });
}

class _FakeBluetoothPrinter implements LabelPrinter {
  @override
  Future<void> connect(PrinterDevice device) async {}

  @override
  Future<List<PrinterDevice>> discover() async => const <PrinterDevice>[
    PrinterDevice(
      id: 'AA:BB:CC:DD:EE:FF#tspl',
      name: 'Pocket label printer — barcode labels (TSPL)',
      kind: PrinterKind.bluetooth,
      protocol: PrinterProtocol.tspl,
    ),
  ];

  @override
  Future<void> disconnect() async {}

  @override
  Future<PrintResult> printLabels(PrintRequest request) async =>
      const PrintResult(succeeded: true);
}
