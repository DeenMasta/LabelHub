import '../../../core/database/app_database.dart';
import '../../../core/printing/label_printer.dart';
import '../domain/entities/printer_profile.dart';

/// Owns persistence and validation for named printer destinations.
class PrinterProfileRepository {
  PrinterProfileRepository(this._database);

  final AppDatabase _database;

  Future<List<PrinterProfile>> list() async {
    final profiles = await _database.printerProfiles();
    return profiles
        .map(
          (DatabasePrinterProfile profile) => PrinterProfile(
            id: profile.id,
            name: profile.name,
            kind: PrinterKind.values.byName(profile.printerKind),
            protocol: PrinterProtocol.values.byName(profile.printerProtocol),
            address: profile.address,
            port: profile.port,
          ),
        )
        .toList();
  }

  Future<void> saveNetwork({
    required String id,
    required String name,
    required String host,
    required int port,
    required PrinterProtocol protocol,
  }) async {
    final trimmedName = name.trim();
    final trimmedHost = host.trim();
    if (trimmedName.isEmpty) {
      throw const PrinterProfileException(
        'Enter a name for the printer profile.',
      );
    }
    if (trimmedHost.isEmpty) {
      throw const PrinterProfileException(
        'Enter the printer IP address or host name.',
      );
    }
    if (port < 1 || port > 65535) {
      throw const PrinterProfileException(
        'Enter a network port from 1 to 65535.',
      );
    }
    if (!<PrinterProtocol>{
      PrinterProtocol.tspl,
      PrinterProtocol.zpl,
      PrinterProtocol.escPos,
    }.contains(protocol)) {
      throw const PrinterProfileException(
        'Select a direct-printer command language.',
      );
    }
    await _database.savePrinterProfile(
      id: id,
      name: trimmedName,
      printerKind: PrinterKind.network.name,
      printerProtocol: protocol.name,
      address: trimmedHost,
      port: port,
    );
  }

  Future<void> delete(String id) => _database.deletePrinterProfile(id);
}

class PrinterProfileException implements Exception {
  const PrinterProfileException(this.message);

  final String message;
}
