import 'bluetooth_thermal_printer.dart';
import 'label_printer.dart';
import 'usb_thermal_printer.dart';

/// Coordinates printer adapters without exposing platform details to UI code.
class PrinterCatalog {
  PrinterCatalog({LabelPrinter? bluetoothPrinter, LabelPrinter? usbPrinter})
    : _bluetoothPrinter = bluetoothPrinter ?? BluetoothThermalPrinter(),
      _usbPrinter = usbPrinter ?? UsbThermalPrinter();

  final LabelPrinter _bluetoothPrinter;
  final LabelPrinter _usbPrinter;

  Future<List<PrinterDevice>> discoverBluetooth() {
    return _bluetoothPrinter.discover();
  }

  Future<List<PrinterDevice>> discoverUsb() => _usbPrinter.discover();

  LabelPrinter get bluetoothPrinter => _bluetoothPrinter;
  LabelPrinter get usbPrinter => _usbPrinter;

  LabelPrinter printerFor(PrinterConnectionType connectionType) =>
      switch (connectionType) {
        PrinterConnectionType.bluetooth => _bluetoothPrinter,
        PrinterConnectionType.usb => _usbPrinter,
      };
}
