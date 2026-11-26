import 'dart:typed_data';

import 'package:barcode/barcode.dart';

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
      for (var copy = 0; copy < label.copies; copy++) {
        _writeLine(
          commands,
          'SIZE ${_millimetres(request.labelWidthMm)} mm,${_millimetres(request.labelHeightMm)} mm',
        );
        _writeLine(commands, 'DIRECTION 1');
        _writeLine(commands, 'CLS');

        if (request.isPriceLabel) {
          _writePriceLabel(commands, label);
          _writeLine(commands, 'PRINT 1,1');
          continue;
        }

        final maxDots = ((request.labelWidthMm - 6) * 8).floor();
        final largeLimit = maxDots ~/ 24;
        final mediumLimit = maxDots ~/ 16;
        final smallLimit = maxDots ~/ 12;
        if (largeLimit < 1 || smallLimit < 1) {
          throw const FormatException('Label is too narrow for product text.');
        }
        final name = label.primaryText.trim();
        final font = name.length <= largeLimit
            ? '4'
            : name.length <= mediumLimit
            ? '3'
            : '2';
        final nameLines = font != '2'
            ? <String>[name]
            : _wrapName(name, smallLimit);
        if (nameLines.length > 3) {
          throw const FormatException(
            'Product name is too long to fit on this label.',
          );
        }
        for (var i = 0; i < nameLines.length; i++) {
          _writeLine(
            commands,
            'TEXT 24,${12 + i * 22},"$font",0,1,1,"${_escape(nameLines[i])}"',
          );
        }
        final secondaryY =
            12 + (nameLines.length - 1) * 22 + (font == '4' ? 32 : 24) + 4;
        final barcodeY = secondaryY + 24;
        _writeLine(
          commands,
          'TEXT 24,$secondaryY,"2",0,1,1,"${_escape(label.secondaryText)}"',
        );
        _writeBarcode(
          commands,
          label,
          labelWidthMm: request.labelWidthMm,
          y: barcodeY,
          textY: barcodeY + 54,
        );
        _writeDates(
          commands,
          label,
          y: barcodeY + 80,
          labelWidthMm: request.labelWidthMm,
        );

        _writeLine(commands, 'PRINT 1,1');
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
      label.expiryDate,
      label.receiveDate,
    ]) {
      if (value.contains('\r') || value.contains('\n')) {
        throw const FormatException(
          'Label fields cannot contain line breaks for direct TSPL printing.',
        );
      }
    }
  }

  void _writePriceLabel(StringBuffer commands, PrintLabelData label) {
    final nameLines = TextUtils.splitToTwoLines(
      label.primaryText,
      limit: 16,
      limitLine2: 24,
    );
    _writeLine(commands, 'TEXT 24,20,"3",0,1,1,"${_escape(nameLines[0])}"');
    if (nameLines.length == 2) {
      _writeLine(commands, 'TEXT 24,50,"2",0,1,1,"${_escape(nameLines[1])}"');
    }
    _writeLine(
      commands,
      'TEXT 24,${nameLines.length == 2 ? 100 : 84},"2",0,2,2,"${_escape(label.secondaryText)}"',
    );
    _writeDates(commands, label, y: nameLines.length == 2 ? 168 : 160);
  }

  List<String> _wrapName(String name, int limit) {
    final lines = <String>[];
    var remaining = name;
    while (remaining.length > limit) {
      final space = remaining.lastIndexOf(' ', limit);
      final end = space > 0 ? space : limit;
      lines.add(remaining.substring(0, end));
      remaining = remaining.substring(end).trimLeft();
    }
    lines.add(remaining);
    return lines;
  }

  void _writeBarcode(
    StringBuffer commands,
    PrintLabelData label, {
    required double labelWidthMm,
    required int y,
    required int textY,
  }) {
    if (label.barcodeValue.isEmpty) {
      return;
    }
    if (label.barcodeValue.codeUnits.any((code) => code < 32 || code > 126)) {
      throw const FormatException(
        'Barcode must contain printable ASCII characters.',
      );
    }
    try {
      Barcode.code128().verify(label.barcodeValue);
    } on BarcodeException catch (error) {
      throw FormatException(error.message);
    }
    final widthDots = (labelWidthMm * 203 / 25.4).round();
    final value = label.barcodeValue;
    final numeric = RegExp(r'^\d+$').hasMatch(value);
    final dataCodes = numeric
        ? (value.length + 1) ~/ 2 + (value.length.isOdd ? 1 : 0)
        : value.length;
    final modules = (dataCodes + 2) * 11 + 13 + 20;
    final moduleWidth = modules * 2 <= widthDots ? 2 : 1;
    if (modules > widthDots) {
      throw const FormatException('Barcode is too long to fit on this label.');
    }
    // shortcut: automatic Code 128 compression can shift the barcode left,
    // use verified printer-specific measurements when the model is known.
    final barcodeX = ((widthDots - (modules - 20) * moduleWidth) / 2).round();
    _writeLine(
      commands,
      'BARCODE $barcodeX,$y,"128",52,0,0,$moduleWidth,$moduleWidth,"${_escape(label.barcodeValue)}"',
    );
    _writeLine(
      commands,
      'TEXT ${_centerTextX(labelWidthMm, label.barcodeValue, 12)},$textY,"1",0,1,1,"${_escape(label.barcodeValue)}"',
    );
  }

  void _writeDates(
    StringBuffer commands,
    PrintLabelData label, {
    required int y,
    double? labelWidthMm,
  }) {
    final expiryText = _dateText('EXP', label.expiryDate);
    final receiveText = _dateText('RCV', label.receiveDate);
    if (expiryText == null && receiveText == null) {
      return;
    }

    final receiveDateOffsetDots = labelWidthMm == null ? 16 : 20;
    if (expiryText != null) {
      _writeLine(
        commands,
        'TEXT ${labelWidthMm == null ? 24 : _centerTextX(labelWidthMm, expiryText, 12)},$y,"1",0,1,1,"${_escape(expiryText)}"',
      );
    }
    if (receiveText != null) {
      _writeLine(
        commands,
        'TEXT ${labelWidthMm == null ? 24 : _centerTextX(labelWidthMm, receiveText, 12)},${expiryText == null ? y : y + receiveDateOffsetDots},"1",0,1,1,"${_escape(receiveText)}"',
      );
    }
  }

  String? _dateText(String label, String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : '$label:$trimmed';
  }

  int _centerTextX(double labelWidthMm, String text, int characterWidth) =>
      (((labelWidthMm * 203 / 25.4) - text.length * characterWidth) / 2)
          .round()
          .clamp(0, 0x7fffffff);

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
