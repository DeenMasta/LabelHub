import '../../../templates/domain/entities/import_template.dart';

/// Validated source data and physical bounds for a barcode render.
class BarcodeRequest {
  const BarcodeRequest({
    required this.value,
    required this.format,
    required this.widthMm,
    required this.heightMm,
    required this.showText,
  });

  final String value;
  final BarcodeFormat format;
  final double widthMm;
  final double heightMm;
  final bool showText;
}

/// A black rectangle in a barcode, expressed in millimetres.
class BarcodeMark {
  const BarcodeMark({
    required this.leftMm,
    required this.topMm,
    required this.widthMm,
    required this.heightMm,
  });

  final double leftMm;
  final double topMm;
  final double widthMm;
  final double heightMm;
}

/// A barcode preview that either contains validated draw marks or an error.
class BarcodePreview {
  const BarcodePreview.valid({
    required this.widthMm,
    required this.heightMm,
    required this.marks,
  }) : errorMessage = null;

  const BarcodePreview.invalid(this.errorMessage)
    : widthMm = 0,
      heightMm = 0,
      marks = const <BarcodeMark>[];

  final double widthMm;
  final double heightMm;
  final List<BarcodeMark> marks;
  final String? errorMessage;

  bool get isValid => errorMessage == null;
}
