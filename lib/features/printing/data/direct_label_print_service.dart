import '../../../core/printing/label_printer.dart';
import '../../../core/printing/printer_catalog.dart';
import '../../labels/domain/entities/label_layout.dart';
import '../../records/domain/entities/catalogue_record.dart';
import '../domain/entities/printer_profile.dart';
import 'printer_profile_repository.dart';

/// Prepares and sends labels to the configured default printer.
///
/// Keeping this workflow outside a page lets entry points such as a catalogue
/// record print directly without duplicating printer setup or command data.
class DirectLabelPrintService {
  DirectLabelPrintService({
    required PrinterProfileRepository printerProfiles,
    required PrinterCatalog printerCatalog,
  }) : _printerProfiles = printerProfiles,
       _printerCatalog = printerCatalog;

  final PrinterProfileRepository _printerProfiles;
  final PrinterCatalog _printerCatalog;

  /// Measures the installed media only when the operator explicitly requests
  /// it. Calibration feeds labels and must not run as part of every job.
  Future<void> calibrateMedia({required LabelLayout layout}) async {
    final selectedProfile = await _defaultProfile();
    final selectedPrinter = selectedProfile.toDevice();
    final printer = _printerCatalog.printerFor(selectedProfile.connectionType);
    var completed = false;
    try {
      if (printer is! TsplMediaCalibratingPrinter) {
        throw const DirectLabelPrintException(
          'The selected printer does not support label media calibration.',
        );
      }
      final calibratingPrinter = printer as TsplMediaCalibratingPrinter;
      await printer.connect(selectedPrinter);
      final result = await calibratingPrinter.calibrateTsplMedia(
        widthMm: layout.widthMm,
        heightMm: layout.heightMm,
      );
      if (!result.succeeded) {
        throw DirectLabelPrintException(
          result.message ?? 'The printer could not calibrate the label media.',
        );
      }
      completed = true;
    } finally {
      if (!completed ||
          selectedProfile.connectionType != PrinterConnectionType.bluetooth) {
        try {
          await printer.disconnect();
        } on Exception {
          // A best-effort transport close must not mask the calibration outcome.
        }
      }
    }
  }

  Future<void> print({
    required List<CatalogueRecord> records,
    required Map<String, int> recordCopies,
    required LabelLayout layout,
    required String primaryFieldKey,
    required String secondaryFieldKey,
  }) async {
    if (records.isEmpty) {
      throw const DirectLabelPrintException(
        'Choose at least one label to print.',
      );
    }

    final selectedProfile = await _defaultProfile();
    final selectedPrinter = selectedProfile.toDevice();
    LabelPrinter? connectedPrinter;
    var completed = false;
    try {
      connectedPrinter = _printerCatalog.printerFor(selectedProfile.connectionType);
      await connectedPrinter.connect(selectedPrinter);
      final result = await connectedPrinter.printLabels(
        PrintRequest(
          recordIds: records
              .map((CatalogueRecord record) => record.id)
              .toList(),
          labels: records
              .map(
                (CatalogueRecord record) => PrintLabelData(
                  primaryText: _fieldValue(record, primaryFieldKey),
                  secondaryText: _fieldValue(record, secondaryFieldKey),
                  barcodeValue: record.barcodeValue,
                  copies: recordCopies[record.id] ?? 1,
                  expiryDate: _fieldValue(record, 'expiry_date'),
                  receiveDate: _fieldValue(record, 'receive_date'),
                ),
              )
              .toList(),
          labelWidthMm: layout.widthMm,
          labelHeightMm: layout.heightMm,
          isPriceLabel: layout.isPriceLabel,
        ),
      );
      if (!result.succeeded) {
        throw DirectLabelPrintException(
          result.message ?? 'The printer could not complete the print job.',
        );
      }
      completed = true;
    } finally {
      if (connectedPrinter != null &&
          (!completed ||
              selectedProfile.connectionType !=
                  PrinterConnectionType.bluetooth)) {
        try {
          await connectedPrinter.disconnect();
        } on Exception {
          // A best-effort socket close must not mask the print outcome.
        }
      }
    }
  }

  Future<PrinterProfile> _defaultProfile() async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _printerProfiles.list(),
      _printerProfiles.defaultProfileId(),
    ]);
    final profiles = results[0]! as List<PrinterProfile>;
    final defaultProfileId = results[1] as String?;
    final selectedProfile = switch (defaultProfileId) {
      null => null,
      final String id =>
        profiles
            .where((PrinterProfile profile) => profile.id == id)
            .firstOrNull,
    };
    if (selectedProfile == null) {
      throw const DirectLabelPrintException(
        'Set a default printer in Settings before printing labels.',
      );
    }
    return selectedProfile;
  }

  String _fieldValue(CatalogueRecord record, String fieldKey) =>
      record.values[fieldKey]?.trim() ?? '';
}

class DirectLabelPrintException implements Exception {
  const DirectLabelPrintException(this.message);

  final String message;

  @override
  String toString() => message;
}
