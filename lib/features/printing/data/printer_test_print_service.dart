import '../../../core/printing/label_printer.dart';
import '../../../core/printing/printer_catalog.dart';
import '../domain/entities/printer_profile.dart';

/// Sends a small known-good TSPL label so an operator can verify a configured
/// printer independently of imported catalogue data.
class PrinterTestPrintService {
  PrinterTestPrintService({required PrinterCatalog printerCatalog})
    : _printerCatalog = printerCatalog;

  final PrinterCatalog _printerCatalog;

  Future<void> printTestLabel(PrinterProfile profile) async {
    final printer = _printerCatalog.printerFor(profile.connectionType);
    try {
      await printer.connect(profile.toDevice());
      final result = await printer.printLabels(
        const PrintRequest(
          recordIds: <String>[],
          labels: <PrintLabelData>[
            PrintLabelData(
              primaryText: 'LabelHub test',
              secondaryText: 'TSPL connection check',
              barcodeValue: 'TEST-123456',
              copies: 1,
            ),
          ],
          labelWidthMm: 50,
          labelHeightMm: 30,
        ),
      );
      if (!result.succeeded) {
        throw PrinterTestPrintException(
          result.message ?? 'The printer did not accept the test label.',
        );
      }
    } finally {
      try {
        await printer.disconnect();
      } on Exception {
        // A best-effort transport close must not mask the test result.
      }
    }
  }
}

class PrinterTestPrintException implements Exception {
  const PrinterTestPrintException(this.message);

  final String message;

  @override
  String toString() => message;
}
