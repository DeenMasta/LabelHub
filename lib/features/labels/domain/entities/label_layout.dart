/// Physical dimensions for the fixed product-label layout.
///
/// Measurements remain in millimetres until a screen or print renderer draws
/// the layout.
class LabelLayout {
  const LabelLayout({
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.horizontalPaddingMm,
    required this.verticalPaddingMm,
    required this.barcodeWidthMm,
    required this.barcodeHeightMm,
  });

  final String name;
  final double widthMm;
  final double heightMm;
  final double horizontalPaddingMm;
  final double verticalPaddingMm;
  final double barcodeWidthMm;
  final double barcodeHeightMm;

  double get aspectRatio => widthMm / heightMm;
}

const productLabelLayout = LabelLayout(
  name: 'Product label',
  widthMm: 58,
  heightMm: 40,
  horizontalPaddingMm: 3,
  verticalPaddingMm: 3,
  barcodeWidthMm: 52,
  barcodeHeightMm: 15,
);
