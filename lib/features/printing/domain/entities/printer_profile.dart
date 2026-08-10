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
    if (kind != PrinterKind.network || port == null) {
      throw StateError(
        'Only network printer profiles can be printed directly.',
      );
    }
    return PrinterDevice(
      id: NetworkPrinterEndpoint.deviceId(host: address, port: port!),
      name: name,
      kind: kind,
      protocol: protocol,
    );
  }
}
