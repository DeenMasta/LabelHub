import 'package:flutter/services.dart';

import 'label_printer.dart';
import 'tspl_label_command_encoder.dart';

/// Prints to Android USB host-mode printers exposed by the platform channel.
class UsbThermalPrinter implements LabelPrinter, TsplMediaCalibratingPrinter {
  UsbThermalPrinter({
    MethodChannel channel = const MethodChannel('labelhub/usb_printer'),
  }) : _channel = channel;

  final MethodChannel _channel;
  PrinterDevice? _connectedDevice;

  @override
  Future<List<PrinterDevice>> discover() async {
    final devices = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listDevices',
    );
    return <PrinterDevice>[
      for (final device in devices ?? const <Map<Object?, Object?>>[])
        ..._devicesFor(device),
    ];
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    if (device.kind != PrinterKind.usb) {
      throw ArgumentError.value(device, 'device', 'Expected a USB printer.');
    }
    await _channel.invokeMethod<void>('connect', <String, Object?>{
      'deviceId': _deviceIdFor(device.id),
    });
    _connectedDevice = device;
  }

  @override
  Future<void> disconnect() async {
    _connectedDevice = null;
    await _channel.invokeMethod<void>('disconnect');
  }

  @override
  Future<PrintResult> printLabels(PrintRequest request) async {
    if (_connectedDevice == null) {
      return const PrintResult(
        succeeded: false,
        message: 'Connect a USB printer before printing.',
      );
    }
    try {
      final commands = const TsplLabelCommandEncoder().encode(request);
      await _channel.invokeMethod<void>('write', commands);
      return const PrintResult(succeeded: true);
    } on Exception catch (error) {
      return PrintResult(succeeded: false, message: error.toString());
    }
  }

  @override
  Future<PrintResult> calibrateTsplMedia({
    required double widthMm,
    required double heightMm,
  }) async {
    if (_connectedDevice == null) {
      return const PrintResult(
        succeeded: false,
        message: 'Connect a USB printer before calibrating media.',
      );
    }
    try {
      await _channel.invokeMethod<void>(
        'write',
        const TsplLabelCommandEncoder().mediaCalibration(
          widthMm: widthMm,
          heightMm: heightMm,
        ),
      );
      return const PrintResult(succeeded: true);
    } on Exception catch (error) {
      return PrintResult(succeeded: false, message: error.toString());
    }
  }

  Iterable<PrinterDevice> _devicesFor(Map<Object?, Object?> device) sync* {
    final id = device['id']?.toString();
    if (id == null || id.isEmpty) {
      return;
    }
    final name = device['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'USB printer $id' : name;
    yield PrinterDevice(
      id: '$id#tspl',
      name: '$displayName — barcode labels (TSPL)',
      kind: PrinterKind.usb,
    );
  }

  String _deviceIdFor(String id) => id.split('#').first;
}
