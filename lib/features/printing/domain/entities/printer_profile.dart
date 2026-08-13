import '../../../../core/printing/label_printer.dart';

/// A named, locally stored direct-printer destination.
class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.name,
    required this.address,
  });

  final String id;
  final String name;
  final String address;

  PrinterDevice toDevice() {
    return PrinterDevice(id: '$address#tspl', name: name);
  }
}
