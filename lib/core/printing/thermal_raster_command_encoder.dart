import 'dart:typed_data';

import 'package:image/image.dart' as image;

/// Encodes monochrome raster images for common thermal-printer languages.
///
/// Keeping this conversion at the printer boundary ensures layouts continue to
/// use millimetres everywhere else in the application.
class ThermalRasterCommandEncoder {
  const ThermalRasterCommandEncoder();

  Uint8List escPos(image.Image raster, {int threshold = 160}) {
    final bitmap = _bitmap(raster, threshold: threshold);
    final widthBytes = (raster.width + 7) ~/ 8;
    final bytes = BytesBuilder(copy: false)
      ..add(const <int>[0x1b, 0x40])
      ..add(<int>[
        0x1d,
        0x76,
        0x30,
        0x00,
        widthBytes & 0xff,
        widthBytes >> 8,
        raster.height & 0xff,
        raster.height >> 8,
      ])
      ..add(bitmap);
    return bytes.toBytes();
  }

  Uint8List tspl(
    image.Image raster, {
    required double widthMm,
    required double heightMm,
    int threshold = 160,
  }) {
    final bitmap = _bitmap(raster, threshold: threshold);
    final widthBytes = (raster.width + 7) ~/ 8;
    final header =
        'SIZE ${_millimetres(widthMm)},${_millimetres(heightMm)}\r\n'
        'GAP 2 mm,0 mm\r\n'
        'DIRECTION 1\r\n'
        'CLS\r\n'
        'BITMAP 0,0,$widthBytes,${raster.height},0,';
    final bytes = BytesBuilder(copy: false)
      ..add(_ascii(header))
      ..add(bitmap)
      ..add(_ascii('\r\nPRINT 1,1\r\n'));
    return bytes.toBytes();
  }

  Uint8List _bitmap(image.Image raster, {required int threshold}) {
    final widthBytes = (raster.width + 7) ~/ 8;
    final bytes = Uint8List(widthBytes * raster.height);
    for (var y = 0; y < raster.height; y++) {
      for (var x = 0; x < raster.width; x++) {
        final pixel = raster.getPixel(x, y);
        // PDF raster pages can retain a transparent page background. Thermal
        // paper is white, so composite alpha onto white before thresholding.
        final luminance =
            pixel.luminance * pixel.aNormalized + 255 * (1 - pixel.aNormalized);
        if (luminance >= threshold) {
          continue;
        }
        final index = y * widthBytes + (x ~/ 8);
        bytes[index] |= 0x80 >> (x % 8);
      }
    }
    return bytes;
  }

  Uint8List _ascii(String value) => Uint8List.fromList(value.codeUnits);

  String _millimetres(double value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
}
