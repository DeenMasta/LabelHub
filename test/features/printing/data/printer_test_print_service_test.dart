import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/core/printing/printer_catalog.dart';
import 'package:labelhub/features/printing/data/printer_test_print_service.dart';
import 'package:labelhub/features/printing/domain/entities/printer_profile.dart';

void main() {
  test('sends a TSPL test label to the selected Bluetooth printer', () async {
    final printer = _FakeLabelPrinter();
    final service = PrinterTestPrintService(
      printerCatalog: PrinterCatalog(bluetoothPrinter: printer),
    );

    await service.printTestLabel(
      const PrinterProfile(
        id: 'wp410',
        name: 'WP410',
        address: 'AA:BB:CC:DD:EE:FF',
      ),
    );

    expect(printer.operations, <String>['connect', 'print', 'disconnect']);
    expect(printer.request!.labels.single.barcodeValue, 'TEST-123456');
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
