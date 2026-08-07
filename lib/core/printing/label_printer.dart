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
  });

  final String id;
  final String name;
  final PrinterKind kind;
}

enum PrinterKind { systemPdf, bluetooth, usb, network }

class PrintRequest {
  const PrintRequest({required this.recordIds, required this.copies});

  final List<String> recordIds;
  final int copies;
}

class PrintResult {
  const PrintResult({required this.succeeded, this.message});

  final bool succeeded;
  final String? message;
}
