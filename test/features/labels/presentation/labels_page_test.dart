import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/features/labels/presentation/labels_page.dart';

void main() {
  testWidgets('configures a generic label preview before choosing products', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: LabelsPage()),
      ),
    );

    expect(find.text('1. Label content'), findsOneWidget);
    expect(find.text('2. General preview'), findsOneWidget);
    expect(find.text('DEMO-123456'), findsOneWidget);
    expect(find.text('Blue T-Shirt'), findsNothing);
    expect(
      tester.getTopLeft(find.text('1. Label content')).dy,
      lessThan(tester.getTopLeft(find.text('2. General preview')).dy),
    );

    final secondLineSelector = find
        .byType(DropdownButtonFormField<String>)
        .at(1);
    await tester.ensureVisible(secondLineSelector);
    await tester.tap(secondLineSelector);
    await tester.pumpAndSettle();

    expect(find.text('No second line'), findsOneWidget);
    expect(find.text('Choose products to print'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
