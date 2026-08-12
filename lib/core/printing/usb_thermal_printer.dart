import 'package:flutter/services.dart';

import 'label_printer.dart';
import 'thermal_raster_command_encoder.dart';
import 'thermal_pdf_rasterizer.dart';
import 'tspl_label_command_encoder.dart';

/// Prints to Android USB host-mode printers exposed by the platform channel.
class UsbThermalPrinter implements LabelPrinter, TsplMediaCalibratingPrinter {
  UsbThermalPrinter({
    MethodChannel channel = const MethodChannel('labelhub/usb_printer'),
    ThermalPdfRasterizer rasterizer = const ThermalPdfRasterizer(),
  }) : _channel = channel,
       _rasterizer = rasterizer;

  final MethodChannel _channel;
  final ThermalPdfRasterizer _rasterizer;
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
    final device = _connectedDevice;
    if (device == null) {
      return const PrintResult(
        succeeded: false,
        message: 'Connect a USB printer before printing.',
      );
    }
    try {
      final commands = device.protocol == PrinterProtocol.tspl
          ? const TsplLabelCommandEncoder().encode(request)
          : await _rasterizer.commandsFor(
              request,
              protocol: device.protocol,
              widthMm: request.labelWidthMm,
              heightMm: request.labelHeightMm,
            );
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
    final device = _connectedDevice;
    if (device == null) {
      return const PrintResult(
        succeeded: false,
        message: 'Connect a USB printer before calibrating media.',
      );
    }
    if (device.protocol != PrinterProtocol.tspl) {
      return const PrintResult(
        succeeded: false,
        message: 'Media calibration is available only for TSPL label printers.',
      );
    }
    try {
      await _channel.invokeMethod<void>(
        'write',
        const ThermalRasterCommandEncoder().tsplMediaCalibration(
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
    for (final protocol in <PrinterProtocol>[
      PrinterProtocol.tspl,
      PrinterProtocol.zpl,
      PrinterProtocol.escPos,
    ]) {
      yield PrinterDevice(
        id: '$id#${protocol.name}',
        name: '$displayName — ${_protocolName(protocol)}',
        kind: PrinterKind.usb,
        protocol: protocol,
      );
    }
  }

  String _deviceIdFor(String id) => id.split('#').first;

  String _protocolName(PrinterProtocol protocol) => switch (protocol) {
    PrinterProtocol.tspl => 'barcode labels (TSPL)',
    PrinterProtocol.zpl => 'barcode labels (ZPL)',
    PrinterProtocol.escPos => 'receipt (ESC/POS)',
  };
}
