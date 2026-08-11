import '../../../../core/printing/label_printer.dart';
import '../../../../core/printing/network_thermal_printer.dart';

/// A named, locally stored direct-printer destination.
class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.name,
    required this.kind,
    required this.protocol,
    required this.address,
    this.port,
  });

  final String id;
  final String name;
  final PrinterKind kind;
  final PrinterProtocol protocol;
  final String address;
  final int? port;

  PrinterDevice toDevice() {
    final id = switch (kind) {
      PrinterKind.network when port != null => NetworkPrinterEndpoint.deviceId(
        host: address,
        port: port!,
      ),
      PrinterKind.bluetooth => '$address#${protocol.name}',
      _ => throw StateError('The printer profile is incomplete.'),
    };
    return PrinterDevice(id: id, name: name, kind: kind, protocol: protocol);
  }
}
