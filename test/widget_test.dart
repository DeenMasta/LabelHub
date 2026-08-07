import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/app.dart';
import 'package:labelhub/features/dashboard/presentation/dashboard_page.dart';

void main() {
  testWidgets('shows the LabelHub dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const LabelHubApp());
    await tester.pumpAndSettle();

    expect(find.text('Print Overview'), findsOneWidget);
    expect(find.byType(DashboardPage), findsOneWidget);
  });
}
