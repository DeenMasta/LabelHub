import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/features/templates/presentation/templates_page.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('shows configurable required fields on a compact phone layout', (
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

    expect(find.text('Item code'), findsOneWidget);
    expect(find.text('Required for barcode labels'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
