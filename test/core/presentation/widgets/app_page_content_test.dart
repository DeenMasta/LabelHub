import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/presentation/widgets/app_page_content.dart';

void main() {
  test('uses compact gutters and full width on phones', () {
    final layout = AppPageLayout.fromWidth(390);

    expect(layout.maxContentWidth, double.infinity);
    expect(layout.horizontalPadding, 20);
    expect(layout.verticalPadding, 24);
  });

  test('uses broader layouts for landscape and wide screens', () {
    final tabletLayout = AppPageLayout.fromWidth(800);
    final desktopLayout = AppPageLayout.fromWidth(1280);

    expect(tabletLayout.maxContentWidth, 880);
    expect(tabletLayout.horizontalPadding, 32);
    expect(desktopLayout.maxContentWidth, 1120);
    expect(desktopLayout.horizontalPadding, 48);
  });
}
