import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/features/labels/domain/entities/label_layout.dart';

void main() {
  test('uses a 40 by 30 mm product label as the default layout', () {
    expect(productLabelLayout.widthMm, 40);
    expect(productLabelLayout.heightMm, 30);
    expect(productLabelLayout.barcodeWidthMm, 34);
    expect(productLabelLayout.barcodeHeightMm, 10);
  });

  test('includes the 30 by 40 mm compact product-label layout', () {
    final layout = productLabelLayoutForId('product-label-30x40');

    expect(productLabelLayouts, contains(compactProductLabelLayout));
    expect(layout.widthMm, 30);
    expect(layout.heightMm, 40);
    expect(layout.barcodeWidthMm, 24);
  });
}
