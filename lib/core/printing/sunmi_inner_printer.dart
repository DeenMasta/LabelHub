import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

import 'label_printer.dart';
import 'thermal_pdf_rasterizer.dart';

/// Sends labels directly to the internal printer service on a Sunmi Android
/// terminal. It deliberately uses ESC/POS raster data so that the same label
/// PDF is printed by both Sunmi receipt hardware and generic receipt printers.
class SunmiInnerPrinter implements LabelPrinter {
  SunmiInnerPrinter({
    SunmiPrinterPlus? sunmiPrinter,
    ThermalPdfRasterizer rasterizer = const ThermalPdfRasterizer(),
  }) : _sunmiPrinter = sunmiPrinter ?? SunmiPrinterPlus(),
       _rasterizer = rasterizer;

  final SunmiPrinterPlus _sunmiPrinter;
  final ThermalPdfRasterizer _rasterizer;
  bool _isConnected = false;

  @override
  Future<List<PrinterDevice>> discover() async => const <PrinterDevice>[
    PrinterDevice(
      id: 'sunmi-inner',
      name: 'Sunmi internal printer',
      kind: PrinterKind.sunmiInner,
      protocol: PrinterProtocol.escPos,
    ),
  ];

  @override
  Future<void> connect(PrinterDevice device) async {
    if (device.kind != PrinterKind.sunmiInner) {
      throw ArgumentError.value(device, 'device', 'Expected a Sunmi printer.');
    }
    final connected = await _sunmiPrinter.rebindPrinter();
    if (!connected) {
      throw const ThermalPrintingException(
        'No Sunmi internal printer is available on this device.',
      );
    }
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  Future<PrintResult> printLabels(PrintRequest request) async {
    if (!_isConnected) {
      return const PrintResult(
        succeeded: false,
        message: 'Connect the Sunmi internal printer before printing.',
      );
    }
    try {
      final commands = await _rasterizer.commandsFor(
        request,
        protocol: PrinterProtocol.escPos,
        widthMm: request.labelWidthMm,
        heightMm: request.labelHeightMm,
      );
      // sunmi_printer_plus casts the channel value to List<Int> in Kotlin.
      // A Uint8List is encoded by Flutter as byte[], so convert explicitly.
      await _sunmiPrinter.printEscPos(commands.toList(growable: false));
      return const PrintResult(succeeded: true);
    } on Exception catch (error) {
      return PrintResult(succeeded: false, message: error.toString());
    }
  }
}
