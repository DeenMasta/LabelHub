import '../../../core/database/app_database.dart';
import '../../../core/printing/label_printer.dart';
import '../domain/entities/printer_profile.dart';

/// Owns persistence and validation for named printer destinations.
class PrinterProfileRepository {
  PrinterProfileRepository(this._database);

  static const _defaultProfileMetadataKey = 'default_printer_profile_id';

  final AppDatabase _database;

  Future<List<PrinterProfile>> list() async {
    final profiles = await _database.printerProfiles();
    return profiles
        .map(
          (DatabasePrinterProfile profile) => PrinterProfile(
            id: profile.id,
            name: profile.name,
            kind: PrinterKind.values.byName(profile.printerKind),
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
    await _database.savePrinterProfile(
      id: id,
      name: trimmedName,
      printerKind: PrinterKind.network.name,
      printerProtocol: 'tspl',
      address: trimmedHost,
      port: port,
    );
  }

  Future<void> saveBluetooth({
    required String id,
    required String name,
    required String address,
  }) async {
    final trimmedName = name.trim();
    final trimmedAddress = address.trim();
    if (trimmedName.isEmpty) {
      throw const PrinterProfileException(
        'Enter a name for the printer profile.',
      );
    }
    if (!RegExp(
      r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$',
    ).hasMatch(trimmedAddress)) {
      throw const PrinterProfileException(
        'The paired Bluetooth printer address is invalid.',
      );
    }
    await _database.savePrinterProfile(
      id: id,
      name: trimmedName,
      printerKind: PrinterKind.bluetooth.name,
      printerProtocol: 'tspl',
      address: trimmedAddress,
    );
  }

  Future<String?> defaultProfileId() async {
    final profileId = await _database.metadataValue(_defaultProfileMetadataKey);
    return profileId == null || profileId.isEmpty ? null : profileId;
  }

  Future<void> setDefault(String profileId) {
    return _database.saveMetadata(
      key: _defaultProfileMetadataKey,
      value: profileId,
    );
  }

  Future<void> delete(String id) async {
    await _database.deletePrinterProfile(id);
    if (await defaultProfileId() == id) {
      await _database.saveMetadata(key: _defaultProfileMetadataKey, value: '');
    }
  }
}

class PrinterProfileException implements Exception {
  const PrinterProfileException(this.message);

  final String message;
}
