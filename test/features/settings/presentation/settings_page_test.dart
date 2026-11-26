import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('returns to settings when Android Back closes printer setup', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: <RouteBase>[
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/settings/printers',
          builder: (_, _) => const Scaffold(body: Text('Printer setup')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );

    await tester.tap(find.text('Printers'));
    await tester.pumpAndSettle();
    expect(find.text('Printer setup'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });
}
