import 'dart:io';

import 'package:flutter/services.dart';

import 'label_printer.dart';
import 'tspl_label_command_encoder.dart';

/// Prints to a USB OTG-connected TSPL printer on Android.
class UsbThermalPrinter implements LabelPrinter, TsplMediaCalibratingPrinter {
  UsbThermalPrinter({
    MethodChannel channel = const MethodChannel('labelhub/usb_printer'),
  }) : _channel = channel;

  final MethodChannel _channel;
  PrinterDevice? _connectedDevice;

  @override
  Future<List<PrinterDevice>> discover() async {
    _ensureAndroid();
    final devices = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listDevices',
    );
    return <PrinterDevice>[
      for (final device in devices ?? const <Map<Object?, Object?>>[])
        if (device['id'] case final String id when id.isNotEmpty)
          PrinterDevice(
            id: id,
            name: _displayName(device['name'], id),
            connectionType: PrinterConnectionType.usb,
          ),
    ];
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    _ensureAndroid();
    await _channel.invokeMethod<void>('connect', <String, Object?>{
      'deviceId': device.id,
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
      return _send(
        await const TsplLabelCommandEncoder().encodeForPrinter(request),
      );
    } on Exception catch (error) {
      return PrintResult(succeeded: false, message: error.toString());
    }
  }

  @override
  Future<PrintResult> calibrateTsplMedia({
    required double widthMm,
    required double heightMm,
  }) {
    if (_connectedDevice == null) {
      return Future<PrintResult>.value(
        const PrintResult(
          succeeded: false,
          message: 'Connect a USB printer before calibrating media.',
        ),
      );
    }
    return _send(
      const TsplLabelCommandEncoder().mediaCalibration(
        widthMm: widthMm,
        heightMm: heightMm,
      ),
    );
  }

  Future<PrintResult> _send(Uint8List commands) async {
    try {
      const chunkSize = 4096;
      for (var start = 0; start < commands.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, commands.length);
        await _channel.invokeMethod<void>(
          'write',
          commands.sublist(start, end),
        );
      }
      return const PrintResult(succeeded: true);
    } on Exception catch (error) {
      return PrintResult(succeeded: false, message: error.toString());
    }
  }

  String _displayName(Object? name, String id) {
    final value = name as String?;
    return value == null || value.trim().isEmpty ? 'USB printer ($id)' : value;
  }

  void _ensureAndroid() {
    if (!Platform.isAndroid) {
      throw const TsplPrintingException(
        'USB thermal printing is currently available on Android only.',
      );
    }
  }
}
