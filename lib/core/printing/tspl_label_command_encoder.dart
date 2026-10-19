import 'dart:typed_data';

import 'label_printer.dart';
import '../utilities/text_utils.dart';

/// Produces native TSPL commands for a 203-DPI product label.
///
/// This uses the printer's text and Code 128 commands instead of rasterizing a
/// bitmap before printing.
class TsplLabelCommandEncoder {
  const TsplLabelCommandEncoder();

  Uint8List encode(PrintRequest request) {
    final commands = StringBuffer();
    for (final label in request.labels) {
      _validate(label);
      _validateCopies(label.copies);
      {
        _writeLine(
          commands,
          'SIZE ${_millimetres(request.labelWidthMm)} mm,${_millimetres(request.labelHeightMm)} mm',
        );
        _writeLine(commands, 'GAP 2 mm,0 mm');
        _writeLine(commands, 'DIRECTION 1');
        _writeLine(commands, 'CLS');

        final nameLines = TextUtils.splitToTwoLines(
          label.primaryText,
          limit: 16,
          limitLine2: 24,
        );
        if (nameLines.length == 1) {
          _writeLine(
            commands,
            'TEXT 24,20,"3",0,1,1,"${_escape(nameLines[0])}"',
          );
          _writeLine(
            commands,
            'TEXT 24,52,"2",0,1,1,"${_escape(label.secondaryText)}"',
          );
          _writeLine(
            commands,
            'BARCODE 24,92,"128",76,0,0,2,2,"${_escape(label.barcodeValue)}"',
          );
          _writeLine(
            commands,
            'TEXT 24,180,"2",0,1,1,"${_escape(label.barcodeValue)}"',
          );
        } else {
          _writeLine(
            commands,
            'TEXT 24,16,"3",0,1,1,"${_escape(nameLines[0])}"',
          );
          _writeLine(
            commands,
            'TEXT 24,46,"2",0,1,1,"${_escape(nameLines[1])}"',
          );
          _writeLine(
            commands,
            'TEXT 24,76,"2",0,1,1,"${_escape(label.secondaryText)}"',
          );
          _writeLine(
            commands,
            'BARCODE 24,110,"128",76,0,0,2,2,"${_escape(label.barcodeValue)}"',
          );
          _writeLine(
            commands,
            'TEXT 24,198,"2",0,1,1,"${_escape(label.barcodeValue)}"',
          );
        }

        _writeLine(commands, 'PRINT 1,${label.copies}');
      }
    }
    return Uint8List.fromList(commands.toString().codeUnits);
  }

  /// Configures the physical label bounds and asks the printer to measure the
  /// gap on the installed media. This moves the media and is intentionally
  /// separate from normal printing.
  Uint8List mediaCalibration({
    required double widthMm,
    required double heightMm,
  }) => _ascii(
    'SIZE ${_millimetres(widthMm)} mm,${_millimetres(heightMm)} mm\r\n'
    'GAPDETECT\r\n',
  );

  void _validate(PrintLabelData label) {
    for (final value in <String>[
      label.primaryText,
      label.secondaryText,
      label.barcodeValue,
    ]) {
      if (value.contains('\r') || value.contains('\n')) {
        throw const FormatException(
          'Label fields cannot contain line breaks for direct TSPL printing.',
        );
      }
    }
    if (label.barcodeValue.isEmpty) {
      throw const FormatException('A barcode value is required for printing.');
    }
  }

  void _validateCopies(int copies) {
    if (copies < 1) {
      throw const FormatException('At least one label copy is required.');
    }
  }

  String _escape(String value) => value.replaceAll('"', r'\"');

  void _writeLine(StringBuffer buffer, String value) =>
      buffer.write('$value\r\n');

  Uint8List _ascii(String value) => Uint8List.fromList(value.codeUnits);

  String _millimetres(double value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
}

class TsplPrintingException implements Exception {
  const TsplPrintingException(this.message);

  final String message;

  @override
  String toString() => message;
}
