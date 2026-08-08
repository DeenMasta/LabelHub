import '../../../core/database/app_database.dart';
import '../domain/entities/catalogue_record.dart';

/// Owns catalogue record persistence and maps database rows to domain records.
class RecordRepository {
  RecordRepository(this._database);

  final AppDatabase _database;

  Future<List<CatalogueRecord>> list() async {
    final records = await _database.records();
    return records.map(_fromDatabase).toList();
  }

  Future<CatalogueRecord?> getById(String id) async {
    final record = await _database.recordById(id);
    return record == null ? null : _fromDatabase(record);
  }

  Future<bool> hasDuplicateBarcode(CatalogueRecord record) {
    return _database.barcodeExistsForAnotherRecord(
      templateId: record.templateId,
      barcodeValue: record.barcodeValue,
      recordId: record.id,
    );
  }

  Future<void> save(CatalogueRecord record) {
    return _database.updateRecord(
      id: record.id,
      reference: record.reference,
      barcodeValue: record.barcodeValue,
      values: record.values,
    );
  }

  Future<void> archive(CatalogueRecord record, {required bool archived}) {
    return _database.setRecordArchived(id: record.id, isArchived: archived);
  }

  Future<void> delete(CatalogueRecord record) =>
      _database.deleteRecord(record.id);

  CatalogueRecord _fromDatabase(DatabaseRecord record) {
    return CatalogueRecord(
      id: record.id,
      templateId: record.templateId,
      reference: record.reference,
      barcodeValue: record.barcodeValue,
      values: record.values,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      isArchived: record.isArchived,
    );
  }
}
