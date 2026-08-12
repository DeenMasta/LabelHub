import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:printing/printing.dart';

import 'label_printer.dart';
import 'thermal_raster_command_encoder.dart';

/// Converts a label PDF into printer-native raster commands at 203 DPI.
class ThermalPdfRasterizer {
  const ThermalPdfRasterizer({
    ThermalRasterCommandEncoder commandEncoder =
        const ThermalRasterCommandEncoder(),
  }) : _commandEncoder = commandEncoder;

  final ThermalRasterCommandEncoder _commandEncoder;

  Future<Uint8List> commandsFor(
    PrintRequest request, {
    required PrinterProtocol protocol,
    required double widthMm,
    required double heightMm,
  }) async {
    final output = BytesBuilder(copy: false);
    await for (final page in Printing.raster(request.pdfBytes, dpi: 203)) {
      final png = await page.toPng();
      final raster = image.decodePng(png);
      if (raster == null) {
        throw const ThermalPrintingException(
          'The label image could not be prepared.',
        );
      }
      output.add(switch (protocol) {
        PrinterProtocol.escPos => _commandEncoder.escPos(raster),
        PrinterProtocol.tspl => _commandEncoder.tspl(
          raster,
          widthMm: widthMm,
          heightMm: heightMm,
        ),
        PrinterProtocol.zpl => _commandEncoder.zpl(
          raster,
          widthMm: widthMm,
          heightMm: heightMm,
        ),
      });
    }
    if (output.length == 0) {
      throw const ThermalPrintingException(
        'The label document has no pages to print.',
      );
    }
    return output.toBytes();
  }
}

class ThermalPrintingException implements Exception {
  const ThermalPrintingException(this.message);

  final String message;

  @override
  String toString() => message;
}
