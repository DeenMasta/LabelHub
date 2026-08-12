import '../../../../core/printing/label_printer.dart';
import '../../../../core/printing/network_thermal_printer.dart';

/// A named, locally stored direct-printer destination.
class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.name,
    required this.kind,
    required this.address,
    this.port,
  });

  final String id;
  final String name;
  final PrinterKind kind;
  final String address;
  final int? port;

  PrinterDevice toDevice() {
    final deviceId = switch (kind) {
      PrinterKind.network when port != null => NetworkPrinterEndpoint.deviceId(
        host: address,
        port: port!,
      ),
      PrinterKind.bluetooth => '$address#tspl',
      _ => throw StateError('The printer profile is incomplete.'),
    };
    return PrinterDevice(id: deviceId, name: name, kind: kind);
  }
}
