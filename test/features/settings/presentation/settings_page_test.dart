import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('shows printer setup in the central settings page', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SettingsPage()),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Printers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
