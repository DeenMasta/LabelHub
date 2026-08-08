import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/validation/import_validation_service.dart';
import '../../templates/domain/entities/import_template.dart';

class ImportRepository {
  ImportRepository(this._database, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final AppDatabase _database;
  final Uuid _uuid;

  Future<Set<String>> existingBarcodes(ImportTemplate template) {
    return _database.barcodeValuesForTemplate(template.id);
  }

  Future<void> saveValidRows({
    required ImportTemplate template,
    required String fileName,
    required ImportValidationResult validation,
  }) async {
    await _database.upsertTemplate(
      id: template.id,
      name: template.name,
      description: template.description,
      barcodeType: template.barcodeFormat.name,
      barcodeFieldKey: template.barcodeFieldKey,
      isSystemTemplate: true,
    );
    await _database.saveImportBatch(
      batchId: _uuid.v4(),
      templateId: template.id,
      fileName: fileName,
      totalRows: validation.rows.length,
      validRows: validation.validRowCount,
      invalidRows: validation.invalidRowCount,
      records: validation.validRows
          .map(
            (ValidatedImportRow row) => DatabaseRecordInsert(
              id: _uuid.v4(),
              reference: row.values['item_code'] ?? row.rowNumber.toString(),
              barcodeValue: row.values[template.barcodeFieldKey] ?? '',
              values: row.values,
            ),
          )
          .toList(),
    );
  }
}
