import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/core/printing/printer_catalog.dart';
import 'package:labelhub/features/printing/presentation/printer_settings_page.dart';

void main() {
  testWidgets('fits printer settings into a compact phone layout and scans', (
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
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Printer connection'), findsOneWidget);
    expect(find.text('Scan for printers'), findsOneWidget);
  });
}

class _FakeBluetoothPrinter implements LabelPrinter {
  @override
  Future<void> connect(PrinterDevice device) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<List<PrinterDevice>> discover() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return const <PrinterDevice>[
      PrinterDevice(
        id: 'AA:BB:CC:DD:EE:FF#tspl',
        name: 'Pocket label printer — barcode labels (TSPL)',
      ),
    ];
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<PrintResult> printLabels(PrintRequest request) async =>
      const PrintResult(succeeded: true);
}
