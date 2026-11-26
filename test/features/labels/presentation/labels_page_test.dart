import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/features/labels/data/label_print_settings_repository.dart';
import 'package:labelhub/features/labels/presentation/labels_page.dart';
import 'package:labelhub/features/labels/domain/entities/label_layout.dart';

void main() {
  late AppDatabase database;
  setUp(
    () async =>
        database = await AppDatabase.openForTesting(NativeDatabase.memory()),
  );
  tearDown(() => database.close());

  test('persists label dimensions and field choices', () async {
    final repository = LabelPrintSettingsRepository(database);
    await repository.save((
      layout: wideProductLabelLayout,
      primaryFieldKey: 'item_code',
      secondaryFieldKey: '',
    ));
    final settings = await LabelPrintSettingsRepository(database).load();
    expect(settings.layout, wideProductLabelLayout);
    expect(settings.primaryFieldKey, 'item_code');
    expect(settings.secondaryFieldKey, '');
  });
  testWidgets('configures a generic label preview before choosing products', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) async => database)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: LabelsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1. Label content'), findsOneWidget);
    expect(find.text('2. General preview'), findsOneWidget);
    expect(find.text('DEMO-123456'), findsOneWidget);
    expect(find.text('EXP:2027-12-31'), findsOneWidget);
    expect(find.text('RCV:2026-11-19'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('EXP:2027-12-31')).textAlign,
      TextAlign.center,
    );
    expect(
      tester.widget<Text>(find.text('RCV:2026-11-19')).textAlign,
      TextAlign.center,
    );
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

  testWidgets(
    'price label preview shows left-aligned name, centered price and barcode',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith((ref) async => database),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: LabelsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<LabelLayout>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Price label').last);
      await tester.pumpAndSettle();
      expect(find.text('DEMO-123456'), findsOneWidget);
      expect(find.text('Price-only layout; barcode is omitted.'), findsNothing);
      final name = tester.widget<Text>(
        find.byKey(const ValueKey<String>('label-preview-primary')),
      );
      final price = tester.widget<Text>(
        find.byKey(const ValueKey<String>('label-preview-secondary')),
      );
      expect(name.textAlign, isNot(TextAlign.center));
      expect(price.textAlign, TextAlign.center);
      expect(price.data, 'RM 8.00');
      expect(find.text('EXP:2027-12-31'), findsNothing);
      expect(find.text('RCV:2026-11-19'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
