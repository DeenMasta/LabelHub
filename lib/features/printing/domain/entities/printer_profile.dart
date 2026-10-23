import '../../../../core/printing/label_printer.dart';

/// A named, locally stored direct-printer destination.
class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.name,
    required this.address,
    this.connectionType = PrinterConnectionType.bluetooth,
  });

  final String id;
  final String name;
  final String address;
  final PrinterConnectionType connectionType;

  PrinterDevice toDevice() {
    final deviceId = switch (connectionType) {
      PrinterConnectionType.bluetooth => '$address#tspl',
      PrinterConnectionType.usb => address,
    };
    return PrinterDevice(
      id: deviceId,
      name: name,
      connectionType: connectionType,
    );
  }
}
