import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:labelhub/core/printing/thermal_raster_command_encoder.dart';

void main() {
  const encoder = ThermalRasterCommandEncoder();

  image.Image sampleRaster() {
    final raster = image.Image(width: 9, height: 2);
    image.fill(raster, color: image.ColorRgb8(255, 255, 255));
    raster.setPixelRgb(0, 0, 0, 0, 0);
    raster.setPixelRgb(8, 1, 0, 0, 0);
    return raster;
  }

  test('encodes a monochrome bitmap as an ESC/POS raster command', () {
    final commands = encoder.escPos(sampleRaster());

    expect(commands.sublist(0, 10), <int>[
      0x1b,
      0x40,
      0x1d,
      0x76,
      0x30,
      0x00,
      2,
      0,
      2,
      0,
    ]);
    expect(commands.sublist(10, 14), <int>[0x80, 0x00, 0x00, 0x80]);
    expect(commands.length, 14);
  });

  test('treats a transparent PDF page background as white thermal paper', () {
    final raster = image.Image(width: 8, height: 1, numChannels: 4);
    image.fill(raster, color: image.ColorRgba8(0, 0, 0, 0));
    raster.setPixelRgba(0, 0, 0, 0, 0, 255);

    final commands = encoder.escPos(raster);

    expect(commands.sublist(10, 11), <int>[0x80]);
  });

  test('encodes a label bitmap with TSPL dimensions and print command', () {
    final commands = encoder.tspl(sampleRaster(), widthMm: 58, heightMm: 40);
    const header =
        'SIZE 58,40\r\n'
        'GAP 2 mm,0 mm\r\n'
        'DIRECTION 1\r\n'
        'CLS\r\n'
        'BITMAP 0,0,2,2,0,';

    expect(commands.sublist(0, header.length), header.codeUnits);
    expect(commands.sublist(header.length, header.length + 4), <int>[
      0x80,
      0x00,
      0x00,
      0x80,
    ]);
    expect(commands.sublist(header.length + 4), '\r\nPRINT 1,1\r\n'.codeUnits);
  });

  test('encodes a label bitmap as a ZPL graphic', () {
    final commands = encoder.zpl(sampleRaster(), widthMm: 58, heightMm: 40);

    expect(
      String.fromCharCodes(commands),
      '^XA\n^PW9\n^LL2\n^FO0,0\n^GFA,4,4,2,80000080^FS\n^XZ\n',
    );
  });
}
