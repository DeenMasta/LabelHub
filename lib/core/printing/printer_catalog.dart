import 'bluetooth_thermal_printer.dart';
import 'label_printer.dart';
import 'sunmi_inner_printer.dart';
import 'system_pdf_printer.dart';

/// Coordinates printer adapters without exposing platform details to UI code.
class PrinterCatalog {
  PrinterCatalog({
    LabelPrinter? systemPrinter,
    LabelPrinter? sunmiPrinter,
    LabelPrinter? bluetoothPrinter,
  }) : _printers = <PrinterKind, LabelPrinter>{
         PrinterKind.systemPdf: systemPrinter ?? SystemPdfPrinter(),
         PrinterKind.sunmiInner: sunmiPrinter ?? SunmiInnerPrinter(),
         PrinterKind.bluetooth: bluetoothPrinter ?? BluetoothThermalPrinter(),
       };

  final Map<PrinterKind, LabelPrinter> _printers;

  Future<List<PrinterDevice>> initialDevices() async {
    final devices = <PrinterDevice>[];
    devices.addAll(await _printers[PrinterKind.systemPdf]!.discover());
    devices.addAll(await _printers[PrinterKind.sunmiInner]!.discover());
    return devices;
  }

  Future<List<PrinterDevice>> discoverBluetooth() {
    return _printers[PrinterKind.bluetooth]!.discover();
  }

  LabelPrinter printerFor(PrinterDevice device) {
    final printer = _printers[device.kind];
    if (printer == null) {
      throw UnsupportedError(
        'No printer adapter is available for ${device.kind}.',
      );
    }
    return printer;
  }
}
