import 'bluetooth_thermal_printer.dart';
import 'label_printer.dart';
import 'network_thermal_printer.dart';
import 'sunmi_inner_printer.dart';
import 'system_pdf_printer.dart';
import 'usb_thermal_printer.dart';

/// Coordinates printer adapters without exposing platform details to UI code.
class PrinterCatalog {
  PrinterCatalog({
    LabelPrinter? systemPrinter,
    LabelPrinter? sunmiPrinter,
    LabelPrinter? bluetoothPrinter,
    LabelPrinter? usbPrinter,
    LabelPrinter? networkPrinter,
  }) : _printers = <PrinterKind, LabelPrinter>{
         PrinterKind.systemPdf: systemPrinter ?? SystemPdfPrinter(),
         PrinterKind.sunmiInner: sunmiPrinter ?? SunmiInnerPrinter(),
         PrinterKind.bluetooth: bluetoothPrinter ?? BluetoothThermalPrinter(),
         PrinterKind.usb: usbPrinter ?? UsbThermalPrinter(),
         PrinterKind.network: networkPrinter ?? NetworkThermalPrinter(),
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

  Future<List<PrinterDevice>> discoverUsb() {
    return _printers[PrinterKind.usb]!.discover();
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
