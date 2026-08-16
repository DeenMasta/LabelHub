import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/app.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/database/database_provider.dart';
import 'package:labelhub/features/dashboard/presentation/dashboard_page.dart';

void main() {
  testWidgets('shows the LabelHub dashboard', (WidgetTester tester) async {
    final database = await AppDatabase.openForTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) async => database),
        ],
        child: const LabelHubApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Label operations'), findsOneWidget);
    expect(find.text('Import products'), findsOneWidget);
    expect(find.byType(DashboardPage), findsOneWidget);
  });
}
