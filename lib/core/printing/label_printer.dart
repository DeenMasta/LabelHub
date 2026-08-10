import 'dart:typed_data';

abstract interface class LabelPrinter {
  Future<List<PrinterDevice>> discover();
  Future<void> connect(PrinterDevice device);
  Future<PrintResult> printLabels(PrintRequest request);
  Future<void> disconnect();
}

class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.protocol,
  });

  final String id;
  final String name;
  final PrinterKind kind;
  final PrinterProtocol protocol;
}

enum PrinterKind { systemPdf, sunmiInner, bluetooth, usb, network }

/// The command language used at the printer boundary.
///
/// ESC/POS is used by receipt printers; TSPL is used by most barcode-label
/// printers. PDF remains available through the Android system print dialog.
enum PrinterProtocol { systemPdf, escPos, tspl }

class PrintRequest {
  const PrintRequest({
    required this.recordIds,
    required this.copies,
    required this.pdfBytes,
    required this.documentName,
    required this.labelWidthMm,
    required this.labelHeightMm,
  });

  final List<String> recordIds;
  final int copies;
  final Uint8List pdfBytes;
  final String documentName;
  final double labelWidthMm;
  final double labelHeightMm;
}

class PrintResult {
  const PrintResult({required this.succeeded, this.message});

  final bool succeeded;
  final String? message;
}
