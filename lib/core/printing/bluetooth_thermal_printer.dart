import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'label_printer.dart';
import 'thermal_pdf_rasterizer.dart';

/// Prints to an already paired Bluetooth SPP printer.
///
/// Receipt printers use ESC/POS while barcode-label printers use TSPL. Pairing
/// is intentionally handled by Android system settings; LabelHub only lists
/// bonded devices and never changes device Bluetooth settings.
class BluetoothThermalPrinter implements LabelPrinter {
  BluetoothThermalPrinter({
    MethodChannel channel = const MethodChannel('labelhub/bluetooth_printer'),
    ThermalPdfRasterizer rasterizer = const ThermalPdfRasterizer(),
  }) : _channel = channel,
       _rasterizer = rasterizer;

  final MethodChannel _channel;
  final ThermalPdfRasterizer _rasterizer;
  PrinterDevice? _connectedDevice;

  @override
  Future<List<PrinterDevice>> discover() async {
    await _requestBluetoothPermission();
    final devices = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listBondedDevices',
    );
    return <PrinterDevice>[
      for (final device in devices ?? const <Map<Object?, Object?>>[])
        ..._devicesFor(device),
    ];
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    if (device.kind != PrinterKind.bluetooth) {
      throw ArgumentError.value(
        device,
        'device',
        'Expected a Bluetooth printer.',
      );
    }
    await _requestBluetoothPermission();
    await _channel.invokeMethod<void>('connect', <String, Object?>{
      'address': _addressFor(device.id),
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
    final device = _connectedDevice;
    if (device == null) {
      return const PrintResult(
        succeeded: false,
        message: 'Connect a Bluetooth printer before printing.',
      );
    }
    try {
      final commands = await _rasterizer.commandsFor(
        request,
        protocol: device.protocol,
        widthMm: request.labelWidthMm,
        heightMm: request.labelHeightMm,
      );
      await _writeInChunks(commands);
      return const PrintResult(succeeded: true);
    } on Exception catch (error) {
      return PrintResult(succeeded: false, message: error.toString());
    }
  }

  Future<void> _requestBluetoothPermission() async {
    if (!Platform.isAndroid) {
      throw const ThermalPrintingException(
        'Bluetooth thermal printing is currently available on Android only.',
      );
    }
    final status = await Permission.bluetoothConnect.request();
    if (!status.isGranted) {
      throw const ThermalPrintingException(
        'Bluetooth permission is required to use paired printers.',
      );
    }
  }

  Future<void> _writeInChunks(Uint8List commands) async {
    const chunkSize = 4096;
    for (var start = 0; start < commands.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, commands.length);
      await _channel.invokeMethod<void>('write', commands.sublist(start, end));
    }
  }

  Iterable<PrinterDevice> _devicesFor(Map<Object?, Object?> device) sync* {
    final address = device['address'] as String?;
    if (address == null || address.isEmpty) {
      return;
    }
    final name = (device['name'] as String?)?.trim();
    final displayName = name == null || name.isEmpty ? address : name;
    yield PrinterDevice(
      id: '$address#escpos',
      name: '$displayName — receipt (ESC/POS)',
      kind: PrinterKind.bluetooth,
      protocol: PrinterProtocol.escPos,
    );
    yield PrinterDevice(
      id: '$address#tspl',
      name: '$displayName — barcode labels (TSPL)',
      kind: PrinterKind.bluetooth,
      protocol: PrinterProtocol.tspl,
    );
  }

  String _addressFor(String id) => id.split('#').first;
}
