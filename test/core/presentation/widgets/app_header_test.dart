import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/active_printer_profile_provider.dart';
import 'package:labelhub/app/theme/app_theme.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/core/presentation/widgets/app_header.dart';
import 'package:labelhub/features/printing/domain/entities/printer_profile.dart';

void main() {
  testWidgets('shows default printer status beside Settings', (
    WidgetTester tester,
  ) async {
    var settingsPressed = false;
    var printerPressed = false;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePrinterProfileProvider.overrideWith(
            (Ref ref) async => const PrinterProfile(
              id: 'warehouse-usb',
              name: 'Warehouse USB printer',
              address: '/dev/bus/usb/001/004',
              connectionType: PrinterConnectionType.usb,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppHeader(
              onPrinterPressed: () => printerPressed = true,
              onSettingsPressed: () => settingsPressed = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final banner = tester.widget<Image>(find.byType(Image));
    expect(
      (banner.image as AssetImage).assetName,
      'assets/labelHub_banner.png',
    );
    expect(find.text('LabelHub'), findsNothing);
    expect(find.text('USB'), findsOneWidget);

    await tester.tap(find.byTooltip('Default printer: Warehouse USB printer (USB)'));
    expect(printerPressed, isTrue);
    await tester.tap(find.byTooltip('Settings'));
    expect(settingsPressed, isTrue);
  });
}
