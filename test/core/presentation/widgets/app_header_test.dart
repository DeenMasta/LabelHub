import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/presentation/widgets/app_header.dart';

void main() {
  testWidgets('uses the LabelHub banner and opens settings', (
    WidgetTester tester,
  ) async {
    var settingsPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppHeader(onSettingsPressed: () => settingsPressed = true),
        ),
      ),
    );

    final banner = tester.widget<Image>(find.byType(Image));
    expect(
      (banner.image as AssetImage).assetName,
      'assets/labelHub_banner.png',
    );
    expect(find.text('LabelHub'), findsNothing);

    await tester.tap(find.byTooltip('Settings'));
    expect(settingsPressed, isTrue);
  });
}
