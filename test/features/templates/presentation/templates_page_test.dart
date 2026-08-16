import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/features/templates/data/builtin_templates.dart';
import 'package:labelhub/features/templates/data/template_settings_repository.dart';
import 'package:labelhub/features/templates/presentation/templates_page.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('shows a guided import flow on a compact phone layout', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TemplatesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Import products'), findsOneWidget);
    expect(find.text('Download CSV'), findsOneWidget);
    expect(find.text('How imports work'), findsOneWidget);
    expect(find.text('Fields and validation'), findsOneWidget);
    expect(find.bySemanticsLabel('Require SKU'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Import products')).dy,
      lessThan(tester.getTopLeft(find.text('Fields and validation')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves an optional field as required', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TemplatesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Require SKU'));
    await tester.pumpAndSettle();

    final template = await TemplateSettingsRepository(
      database,
    ).loadProductTemplate(productTemplate);
    final sku = template.fields.firstWhere((field) => field.key == 'item_code');
    expect(sku.required, isTrue);
    expect(tester.takeException(), isNull);
  });
}
