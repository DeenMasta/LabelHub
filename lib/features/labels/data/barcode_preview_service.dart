import 'package:barcode/barcode.dart';

import '../../templates/domain/entities/import_template.dart';
import '../domain/entities/barcode_request.dart';

/// Validates barcode data and creates renderer-independent barcode marks.
class BarcodePreviewService {
  const BarcodePreviewService();

  BarcodePreview create(BarcodeRequest request) {
    if (request.value.trim().isEmpty) {
      return const BarcodePreview.invalid('A barcode value is required.');
    }
    if (request.widthMm <= 0 || request.heightMm <= 0) {
      return const BarcodePreview.invalid(
        'Barcode dimensions must be greater than zero.',
      );
    }

    final barcode = _barcodeFor(request.format);
    try {
      barcode.verify(request.value);
      final marks = barcode
          .make(
            request.value,
            width: request.widthMm,
            height: request.heightMm,
            drawText: request.showText,
            fontHeight: request.heightMm * .16,
          )
          .whereType<BarcodeBar>()
          .where((BarcodeBar bar) => bar.black)
          .map(
            (BarcodeBar bar) => BarcodeMark(
              leftMm: bar.left,
              topMm: bar.top,
              widthMm: bar.width,
              heightMm: bar.height,
            ),
          )
          .toList();
      return BarcodePreview.valid(
        widthMm: request.widthMm,
        heightMm: request.heightMm,
        marks: marks,
      );
    } on BarcodeException catch (error) {
      return BarcodePreview.invalid(error.message);
    } on Exception {
      return const BarcodePreview.invalid(
        'The barcode could not be generated.',
      );
    }
  }

  Barcode _barcodeFor(BarcodeFormat format) {
    return switch (format) {
      BarcodeFormat.code128 => Barcode.code128(),
      BarcodeFormat.code39 => Barcode.code39(),
      BarcodeFormat.ean13 => Barcode.ean13(),
      BarcodeFormat.qrCode => Barcode.qrCode(),
    };
  }
}
