import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/features/labels/domain/entities/label_layout.dart';

void main() {
  test('includes the 30 by 40 mm compact product-label layout', () {
    final layout = productLabelLayoutForId('product-label-30x40');

    expect(productLabelLayouts, contains(compactProductLabelLayout));
    expect(layout.widthMm, 30);
    expect(layout.heightMm, 40);
    expect(layout.barcodeWidthMm, 24);
  });
}
