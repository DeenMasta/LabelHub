/// A historical record of handing a generated label PDF to a printer.
class PrintJob {
  const PrintJob({
    required this.id,
    required this.printerName,
    required this.labelLayoutId,
    required this.recordCount,
    required this.copies,
    required this.status,
    required this.createdAt,
    required this.completedAt,
    required this.errorMessage,
  });

  final String id;
  final String printerName;
  final String labelLayoutId;
  final int recordCount;
  final int copies;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;

  int get labelCount => recordCount * copies;
  bool get isCompleted => status == 'completed';
}
