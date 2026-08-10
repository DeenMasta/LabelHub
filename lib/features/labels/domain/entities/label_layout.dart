/// Physical dimensions for the fixed product-label layout.
///
/// Measurements remain in millimetres until a screen or print renderer draws
/// the layout.
class LabelLayout {
  const LabelLayout({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.horizontalPaddingMm,
    required this.verticalPaddingMm,
    required this.barcodeWidthMm,
    required this.barcodeHeightMm,
  });

  final String id;
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
  id: 'product-label-58x40',
  name: 'Product label',
  widthMm: 58,
  heightMm: 40,
  horizontalPaddingMm: 3,
  verticalPaddingMm: 3,
  barcodeWidthMm: 52,
  barcodeHeightMm: 15,
);

const compactProductLabelLayout = LabelLayout(
  id: 'product-label-30x40',
  name: 'Compact product label',
  widthMm: 30,
  heightMm: 40,
  horizontalPaddingMm: 3,
  verticalPaddingMm: 3,
  barcodeWidthMm: 24,
  barcodeHeightMm: 15,
);

const productLabelLayouts = <LabelLayout>[
  productLabelLayout,
  compactProductLabelLayout,
];

LabelLayout productLabelLayoutForId(String? id) {
  return productLabelLayouts.firstWhere(
    (LabelLayout layout) => layout.id == id,
    orElse: () => productLabelLayout,
  );
}
