import 'package:printing/printing.dart';

import 'label_printer.dart';

/// Hands a generated PDF to the operating system's available print services.
class SystemPdfPrinter implements LabelPrinter {
  bool _isConnected = false;

  @override
  Future<List<PrinterDevice>> discover() async => const <PrinterDevice>[
    PrinterDevice(
      id: 'system-pdf',
      name: 'System print dialog',
      kind: PrinterKind.systemPdf,
    ),
  ];

  @override
  Future<void> connect(PrinterDevice device) async {
    if (device.kind != PrinterKind.systemPdf) {
      throw ArgumentError.value(device, 'device', 'Expected a system printer.');
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
        message: 'Connect the system printer before printing.',
      );
    }
    try {
      final submitted = await Printing.layoutPdf(
        name: request.documentName,
        onLayout: (_) async => request.pdfBytes,
      );
      return submitted
          ? const PrintResult(succeeded: true)
          : const PrintResult(
              succeeded: false,
              message: 'The print dialog was dismissed before submission.',
            );
    } on Exception catch (error) {
      return PrintResult(succeeded: false, message: error.toString());
    }
  }
}
