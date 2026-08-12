import 'dart:typed_data';

abstract interface class LabelPrinter {
  Future<List<PrinterDevice>> discover();
  Future<void> connect(PrinterDevice device);
  Future<PrintResult> printLabels(PrintRequest request);
  Future<void> disconnect();
}

/// Optional capability for TSPL printers that can measure the currently
/// installed label media with their gap sensor.
abstract interface class TsplMediaCalibratingPrinter {
  Future<PrintResult> calibrateTsplMedia({
    required double widthMm,
    required double heightMm,
  });
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

enum PrinterKind { sunmiInner, bluetooth, usb, network }

/// The command language used at the printer boundary.
///
/// ESC/POS is used by receipt printers; TSPL and ZPL are used by barcode-label
/// printers.
enum PrinterProtocol { escPos, tspl, zpl }

class PrintRequest {
  const PrintRequest({
    required this.recordIds,
    required this.labels,
    required this.copies,
    required this.pdfBytes,
    required this.documentName,
    required this.labelWidthMm,
    required this.labelHeightMm,
  });

  final List<String> recordIds;
  final List<PrintLabelData> labels;
  final int copies;
  final Uint8List pdfBytes;
  final String documentName;
  final double labelWidthMm;
  final double labelHeightMm;
}

/// Printer-independent label content prepared from a product record.
class PrintLabelData {
  const PrintLabelData({
    required this.primaryText,
    required this.secondaryText,
    required this.barcodeValue,
  });

  final String primaryText;
  final String secondaryText;
  final String barcodeValue;
}

class PrintResult {
  const PrintResult({required this.succeeded, this.message});

  final bool succeeded;
  final String? message;
}
