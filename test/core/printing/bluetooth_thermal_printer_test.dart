import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/printing/bluetooth_thermal_printer.dart';
import 'package:labelhub/core/printing/label_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('writes an encoded barcode label to the connected printer', () async {
    const channel = MethodChannel('labelhub/test_bluetooth_printer');
    final calls = <String>[];
    Uint8List? labelBytes;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call.method);
          if (call.method == 'write') {
            labelBytes = call.arguments as Uint8List;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final printer = BluetoothThermalPrinter(
      channel: channel,
      requestBluetoothPermission: () async {},
    );
    await printer.connect(
      const PrinterDevice(id: 'AA:BB:CC:DD:EE:FF#tspl', name: 'Test printer'),
    );

    final result = await printer.printLabels(
      const PrintRequest(
        recordIds: <String>['record-1'],
        labels: <PrintLabelData>[
          PrintLabelData(
            primaryText: 'Item',
            secondaryText: 'RM 10.00',
            barcodeValue: 'ITEM-001',
            copies: 1,
          ),
        ],
        labelWidthMm: 50,
        labelHeightMm: 30,
      ),
    );

    expect(result.succeeded, isTrue);
    expect(calls, <String>['connect', 'write']);
    expect(utf8.decode(labelBytes!), contains('BARCODE 77,108,"128"'));
    expect(utf8.decode(labelBytes!), contains('ITEM-001'));
  });
}
