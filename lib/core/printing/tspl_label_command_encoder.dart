import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';

import 'label_printer.dart';

/// Produces native TSPL commands for a 203-DPI product label.
///
/// Price-label names and prices can be rasterized to avoid printer font differences.
class TsplLabelCommandEncoder {
  const TsplLabelCommandEncoder();

  Future<Uint8List> encodeForPrinter(PrintRequest request) async {
    final encoded = encode(request);
    if (!request.isPriceLabel) return encoded;

    final lines = String.fromCharCodes(encoded).split('\r\n');
    final textPattern = RegExp(
      r'^TEXT (\d+),(\d+),"([2-5])",0,(\d+),(\d+),"((?:\\.|[^"])*)"$',
    );
    final output = BytesBuilder();
    final widthDots = (request.labelWidthMm * 203 / 25.4).round();
    var block = <int>[];
    final priceLines = <int>{};
    for (var i = 0; i < lines.length; i++) {
      if (textPattern.hasMatch(lines[i])) block.add(i);
      if (lines[i] == 'PRINT 1,1') {
        if (block.isNotEmpty) priceLines.add(block.last);
        block = <int>[];
      }
    }
    final cache = <String, Uint8List>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final match = textPattern.firstMatch(line);
      if (match == null) {
        output.add(<int>[...line.codeUnits, 13, 10]);
        continue;
      }
      final text = match[6]!.replaceAll(r'\"', '"');
      if (text.isEmpty) continue;
      final fontHeight = switch (match[3]!) {
        '2' => 20,
        '3' => 24,
        '4' => 32,
        _ => 48,
      };
      final height = fontHeight * int.parse(match[5]!);
      final centered = priceLines.contains(i);
      final key = '$height:$centered:$text';
      final bitmap = cache[key] ??= await _textBitmap(
        text,
        widthDots,
        height,
        centered,
      );
      final widthBytes = (widthDots + 7) ~/ 8;
      output.add('BITMAP 0,${match[2]},$widthBytes,$height,0,'.codeUnits);
      output.add(bitmap);
      output.add(const <int>[13, 10]);
    }
    return output.takeBytes();
  }

  Future<Uint8List> _textBitmap(
    String text,
    int width,
    int height,
    bool centered,
  ) async {
    final paragraph =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textDirection: ui.TextDirection.ltr,
                  fontSize: height * .85,
                  fontWeight: ui.FontWeight.bold,
                  height: 1,
                  maxLines: 1,
                ),
              )
              ..pushStyle(ui.TextStyle(color: const ui.Color(0xff000000)))
              ..addText(text))
            .build()
          ..layout(ui.ParagraphConstraints(width: width.toDouble()));
    final textWidth = paragraph.maxIntrinsicWidth;
    final available = (width - 48).toDouble();
    final scale = textWidth > available ? available / textWidth : 1.0;
    final left = centered ? (width - textWidth * scale) / 2 : 24.0;
    final byteWidth = (width + 7) ~/ 8;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    canvas.translate(left, 0);
    canvas.scale(scale, 1);
    canvas.drawParagraph(paragraph, ui.Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(byteWidth * 8, height);
    picture.dispose();
    paragraph.dispose();
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (rgba == null) {
      throw const FormatException('Could not render label text.');
    }
    final bitmap = Uint8List(byteWidth * height)
      ..fillRange(0, byteWidth * height, 255);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = (y * byteWidth * 8 + x) * 4;
        if (rgba.getUint8(pixel) < 128) {
          bitmap[y * byteWidth + x ~/ 8] &= ~(128 >> (x % 8));
        }
      }
    }
    return bitmap;
  }

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
          _writePriceLabel(commands, label, request);
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
        var font = name.length <= largeLimit
            ? '4'
            : name.length <= mediumLimit
            ? '3'
            : '2';
        var nameLines = font != '2'
            ? <String>[name]
            : _wrapName(name, smallLimit);
        if (nameLines.length > 3) {
          throw const FormatException(
            'Product name is too long to fit on this label.',
          );
        }
        var lineHeight = 22;
        var fontHeight = font == '4' ? 32 : 24;
        var secondaryScale = 1;
        if (label.expiryDate.trim().isEmpty &&
            label.receiveDate.trim().isEmpty) {
          final heightDots = (request.labelHeightMm * 203 / 25.4).floor();
          for (final candidate in <(String, int, int)>[
            ('5', 32, 48),
            ('4', 24, 32),
            ('3', 16, 24),
            ('2', 12, 20),
          ]) {
            final limit = maxDots ~/ candidate.$2;
            if (limit < 1) continue;
            final lines = _wrapName(name, limit);
            final scale = label.secondaryText.length * 24 <= maxDots ? 2 : 1;
            final bottom =
                12 +
                lines.length * candidate.$3 +
                4 +
                (scale == 2 ? 44 : 24) +
                74;
            if (lines.length <= 3 && bottom <= heightDots - 24) {
              font = candidate.$1;
              nameLines = lines;
              lineHeight = candidate.$3;
              fontHeight = candidate.$3;
              secondaryScale = scale;
              break;
            }
          }
        }
        for (var i = 0; i < nameLines.length; i++) {
          _writeLine(
            commands,
            'TEXT 24,${12 + i * lineHeight},"$font",0,1,1,"${_escape(nameLines[i])}"',
          );
        }
        final secondaryY =
            12 + (nameLines.length - 1) * lineHeight + fontHeight + 4;
        final barcodeY = secondaryY + (secondaryScale == 2 ? 44 : 24);
        _writeLine(
          commands,
          'TEXT 24,$secondaryY,"2",0,$secondaryScale,$secondaryScale,"${_escape(label.secondaryText)}"',
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

  void _writePriceLabel(
    StringBuffer commands,
    PrintLabelData label,
    PrintRequest request,
  ) {
    final labelWidthMm = request.labelWidthMm;
    final maxDots = ((labelWidthMm - 6) * 8).floor();
    final limit = maxDots ~/ 12;
    if (limit < 1) {
      throw const FormatException('Label is too narrow for product text.');
    }
    var nameLines = _wrapName(label.primaryText.trim(), limit);
    if (nameLines.length > 3) {
      throw const FormatException(
        'Product name is too long to fit on this label.',
      );
    }
    var price = label.secondaryText.trim();
    if (request.secondaryFieldIsPrice && price.isNotEmpty) {
      final prefix = RegExp(r'^RM(?=\s|[0-9.,+\-]|$)\s*', caseSensitive: false);
      final amount = price.replaceFirst(prefix, '').trim();
      price = amount.isEmpty ? 'RM' : 'RM $amount';
    }
    if (price.length > limit) {
      throw const FormatException('Price is too long to fit on this label.');
    }
    final dateCount =
        (label.expiryDate.trim().isEmpty ? 0 : 1) +
        (label.receiveDate.trim().isEmpty ? 0 : 1);
    final priceFont = dateCount == 0 && price.length * 32 <= maxDots
        ? '3'
        : '2';
    final priceWidth = priceFont == '3' ? 16 : 12;
    final priceScale = price.length * priceWidth * 2 <= maxDots ? 2 : 1;
    final priceHeight = (priceFont == '3' ? 24 : 20) * priceScale;
    final barcodeHeight = dateCount == 2
        ? 40
        : dateCount == 1
        ? 48
        : 52;
    final nameTop = dateCount == 0 ? 12 : 8;
    var nameFont = '2';
    var lineHeight = 22;
    var nameHeight = 20;
    if (dateCount == 0) {
      final heightDots = (request.labelHeightMm * 203 / 25.4).floor();
      for (final candidate in <(String, int, int)>[
        ('5', 32, 48),
        ('4', 24, 32),
        ('3', 16, 24),
        ('2', 12, 20),
      ]) {
        final candidateLimit = maxDots ~/ candidate.$2;
        if (candidateLimit < 1) continue;
        final lines = _wrapName(label.primaryText.trim(), candidateLimit);
        final bottom =
            12 + lines.length * candidate.$3 + 4 + priceHeight + 4 + 74;
        if (lines.length <= 3 && bottom <= heightDots - 16) {
          nameLines = lines;
          nameFont = candidate.$1;
          lineHeight = candidate.$3;
          nameHeight = candidate.$3;
          break;
        }
      }
    } else {
      final heightDots = (request.labelHeightMm * 203 / 25.4).floor();
      var fits = false;
      for (final candidate in <(String, int, int)>[
        ('5', 26, 48),
        ('4', 20, 32),
        ('3', 14, 24),
        ('2', 12, 20),
      ]) {
        final candidateLimit = maxDots ~/ candidate.$2;
        if (candidateLimit < 1) continue;
        final lines = _wrapName(label.primaryText.trim(), candidateLimit);
        final bottom =
            nameTop +
            lines.length * candidate.$3 +
            4 +
            priceHeight +
            4 +
            barcodeHeight +
            30 +
            (dateCount - 1) * 22 +
            20;
        if (lines.length <= 3 && bottom <= heightDots - 8) {
          nameLines = lines;
          nameFont = candidate.$1;
          lineHeight = candidate.$3;
          nameHeight = candidate.$3;
          fits = true;
          break;
        }
      }
      if (!fits) {
        throw const FormatException(
          'Product name and dates cannot fit on this label.',
        );
      }
    }
    for (var i = 0; i < nameLines.length; i++) {
      _writeLine(
        commands,
        'TEXT 24,${nameTop + i * lineHeight},"$nameFont",0,1,1,"${_escape(nameLines[i])}"',
      );
    }
    final priceY =
        nameTop + (nameLines.length - 1) * lineHeight + nameHeight + 4;
    _writeLine(
      commands,
      'TEXT ${_centerTextX(labelWidthMm, price, priceWidth * priceScale)},$priceY,"$priceFont",0,$priceScale,$priceScale,"${_escape(price)}"',
    );
    final barcodeY = priceY + priceHeight + 4;
    _writeBarcode(
      commands,
      label,
      labelWidthMm: labelWidthMm,
      y: barcodeY,
      height: barcodeHeight,
      textY: barcodeY + barcodeHeight + 2,
    );
    _writeDates(
      commands,
      label,
      y: barcodeY + barcodeHeight + 30,
      lineSpacing: 22,
    );
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
    int height = 52,
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
      'BARCODE $barcodeX,$y,"128",$height,0,0,$moduleWidth,$moduleWidth,"${_escape(label.barcodeValue)}"',
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
    int? lineSpacing,
  }) {
    final expiryText = _dateText('EXP', label.expiryDate);
    final receiveText = _dateText('RCV', label.receiveDate);
    if (expiryText == null && receiveText == null) {
      return;
    }

    final receiveDateOffsetDots =
        lineSpacing ?? (labelWidthMm == null ? 16 : 20);
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
