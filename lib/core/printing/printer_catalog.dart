import 'bluetooth_thermal_printer.dart';
import 'label_printer.dart';

/// Coordinates printer adapters without exposing platform details to UI code.
class PrinterCatalog {
  PrinterCatalog({LabelPrinter? bluetoothPrinter})
    : _bluetoothPrinter = bluetoothPrinter ?? BluetoothThermalPrinter();

  final LabelPrinter _bluetoothPrinter;

  Future<List<PrinterDevice>> discoverBluetooth() {
    return _bluetoothPrinter.discover();
  }

  LabelPrinter get bluetoothPrinter => _bluetoothPrinter;
}
