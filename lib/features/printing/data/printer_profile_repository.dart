import '../../../core/database/app_database.dart';
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
            address: profile.address,
          ),
        )
        .toList();
  }

  Future<void> saveProfile({
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
      printerKind: 'bluetooth',
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
