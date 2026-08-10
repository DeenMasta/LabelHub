import 'dart:io';

import 'label_printer.dart';
import 'thermal_pdf_rasterizer.dart';

/// Sends rasterized commands to a printer's TCP raw-print port.
///
/// Network devices are deliberately supplied by a saved printer profile rather
/// than being scanned automatically. This keeps the offline app predictable on
/// managed networks and avoids sending traffic to unknown hosts.
class NetworkThermalPrinter implements LabelPrinter {
  NetworkThermalPrinter({
    ThermalPdfRasterizer rasterizer = const ThermalPdfRasterizer(),
  }) : _rasterizer = rasterizer;

  final ThermalPdfRasterizer _rasterizer;
  Socket? _socket;
  PrinterDevice? _connectedDevice;

  @override
  Future<List<PrinterDevice>> discover() async => const <PrinterDevice>[];

  @override
  Future<void> connect(PrinterDevice device) async {
    if (device.kind != PrinterKind.network) {
      throw ArgumentError.value(
        device,
        'device',
        'Expected a network printer.',
      );
    }
    final endpoint = NetworkPrinterEndpoint.fromDeviceId(device.id);
    await disconnect();
    _socket = await Socket.connect(
      endpoint.host,
      endpoint.port,
      timeout: const Duration(seconds: 8),
    );
    _connectedDevice = device;
  }

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    _connectedDevice = null;
    await socket?.close();
  }

  @override
  Future<PrintResult> printLabels(PrintRequest request) async {
    final socket = _socket;
    final device = _connectedDevice;
    if (socket == null || device == null) {
      return const PrintResult(
        succeeded: false,
        message: 'Connect a network printer before printing.',
      );
    }
    try {
      final commands = await _rasterizer.commandsFor(
        request,
        protocol: device.protocol,
        widthMm: request.labelWidthMm,
        heightMm: request.labelHeightMm,
      );
      socket.add(commands);
      await socket.flush();
      return const PrintResult(succeeded: true);
    } on SocketException catch (error) {
      return PrintResult(succeeded: false, message: error.message);
    } on Exception catch (error) {
      return PrintResult(succeeded: false, message: error.toString());
    }
  }
}

class NetworkPrinterEndpoint {
  const NetworkPrinterEndpoint({required this.host, required this.port});

  final String host;
  final int port;

  static String deviceId({required String host, required int port}) =>
      'network:$host:$port';

  static NetworkPrinterEndpoint fromDeviceId(String id) {
    final parts = id.split(':');
    if (parts.length < 3 || parts.first != 'network') {
      throw const ThermalPrintingException(
        'The network printer address is invalid.',
      );
    }
    final port = int.tryParse(parts.last);
    final host = parts.sublist(1, parts.length - 1).join(':');
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      throw const ThermalPrintingException(
        'The network printer address is invalid.',
      );
    }
    return NetworkPrinterEndpoint(host: host, port: port);
  }
}
