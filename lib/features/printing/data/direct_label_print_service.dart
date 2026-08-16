import '../../../core/printing/label_printer.dart';
import '../../../core/printing/printer_catalog.dart';
import '../../../core/printing/tspl_label_command_encoder.dart';
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

  Future<void> print({
    required List<CatalogueRecord> records,
    required Map<String, int> recordCopies,
    required LabelLayout layout,
    required String primaryFieldKey,
    required String secondaryFieldKey,
    void Function(bool isCalibrating)? onCalibrationChanged,
  }) async {
    if (records.isEmpty) {
      throw const DirectLabelPrintException(
        'Choose at least one label to print.',
      );
    }

    final selectedPrinter = await _defaultPrinter();
    LabelPrinter? connectedPrinter;
    try {
      connectedPrinter = _printerCatalog.bluetoothPrinter;
      await connectedPrinter.connect(selectedPrinter);
      await _calibrateBeforePrinting(
        connectedPrinter,
        layout,
        onCalibrationChanged,
      );
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
                ),
              )
              .toList(),
          labelWidthMm: layout.widthMm,
          labelHeightMm: layout.heightMm,
        ),
      );
      if (!result.succeeded) {
        throw DirectLabelPrintException(
          result.message ?? 'The printer could not complete the print job.',
        );
      }
    } finally {
      if (connectedPrinter != null) {
        try {
          await connectedPrinter.disconnect();
        } on Exception {
          // A best-effort socket close must not mask the print outcome.
        }
      }
    }
  }

  Future<PrinterDevice> _defaultPrinter() async {
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
    return selectedProfile.toDevice();
  }

  Future<void> _calibrateBeforePrinting(
    LabelPrinter printer,
    LabelLayout layout,
    void Function(bool isCalibrating)? onCalibrationChanged,
  ) async {
    if (printer is! TsplMediaCalibratingPrinter) {
      return;
    }
    final calibratingPrinter = printer as TsplMediaCalibratingPrinter;
    onCalibrationChanged?.call(true);
    try {
      final result = await calibratingPrinter.calibrateTsplMedia(
        widthMm: layout.widthMm,
        heightMm: layout.heightMm,
      );
      if (!result.succeeded) {
        throw TsplPrintingException(
          result.message ?? 'The printer could not calibrate the label media.',
        );
      }
    } finally {
      onCalibrationChanged?.call(false);
    }
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
