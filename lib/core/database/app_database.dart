import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Owns the offline SQLite database and applies schema migrations.
///
/// Tables are deliberately created with versioned SQL during the foundation
/// phase. Feature repositories can move to generated Drift tables without
/// changing the database file or the application's public contracts.
class AppDatabase {
  AppDatabase._(this._executor);

  final QueryExecutor _executor;
  static const _executorUser = _AppDatabaseExecutorUser();

  static Future<AppDatabase> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final databaseFile = File(path.join(directory.path, 'labelhub.sqlite'));
    final executor = NativeDatabase.createInBackground(databaseFile);
    await executor.ensureOpen(_executorUser);
    final database = AppDatabase._(executor);
    await database._migrate();
    return database;
  }

  /// Creates an isolated database for repository tests.
  static Future<AppDatabase> openForTesting(QueryExecutor executor) async {
    await executor.ensureOpen(_executorUser);
    final database = AppDatabase._(executor);
    await database._migrate();
    return database;
  }

  Future<void> _migrate() async {
    await _executor.runCustom('PRAGMA foreign_keys = ON');
    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      )
    ''');
    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS templates (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        barcode_type TEXT NOT NULL,
        barcode_field_key TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_system_template INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS import_batches (
        id TEXT PRIMARY KEY NOT NULL,
        template_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        total_rows INTEGER NOT NULL,
        valid_rows INTEGER NOT NULL,
        invalid_rows INTEGER NOT NULL,
        imported_at TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(template_id) REFERENCES templates(id)
      )
    ''');
    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS records (
        id TEXT PRIMARY KEY NOT NULL,
        template_id TEXT NOT NULL,
        import_batch_id TEXT,
        record_reference TEXT NOT NULL,
        barcode_value TEXT NOT NULL,
        values_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(template_id) REFERENCES templates(id),
        FOREIGN KEY(import_batch_id) REFERENCES import_batches(id)
      )
    ''');
    await _executor.runCustom(
      'CREATE INDEX IF NOT EXISTS records_barcode_idx ON records(barcode_value)',
    );
  }

  Future<void> close() => _executor.close();

  Future<void> upsertTemplate({
    required String id,
    required String name,
    required String description,
    required String barcodeType,
    required String barcodeFieldKey,
    required bool isSystemTemplate,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _executor.runInsert(
      '''
        INSERT INTO templates (
          id, name, description, barcode_type, barcode_field_key,
          created_at, updated_at, is_system_template
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          description = excluded.description,
          barcode_type = excluded.barcode_type,
          barcode_field_key = excluded.barcode_field_key,
          updated_at = excluded.updated_at,
          is_system_template = excluded.is_system_template
      ''',
      <Object?>[
        id,
        name,
        description,
        barcodeType,
        barcodeFieldKey,
        now,
        now,
        isSystemTemplate ? 1 : 0,
      ],
    );
  }

  Future<Set<String>> barcodeValuesForTemplate(String templateId) async {
    final rows = await _executor.runSelect(
      'SELECT barcode_value FROM records WHERE template_id = ? AND is_archived = 0',
      <Object?>[templateId],
    );
    return rows
        .map((Map<String, Object?> row) => row['barcode_value'] as String)
        .toSet();
  }

  Future<List<DatabaseRecord>> records() async {
    final rows = await _executor.runSelect('''
        SELECT id, template_id, record_reference, barcode_value, values_json,
          created_at, updated_at, is_archived
        FROM records
        ORDER BY is_archived ASC, updated_at DESC, record_reference COLLATE NOCASE ASC
      ''', const <Object?>[]);
    return rows.map(DatabaseRecord.fromRow).toList();
  }

  Future<DatabaseRecord?> recordById(String id) async {
    final rows = await _executor.runSelect(
      '''
        SELECT id, template_id, record_reference, barcode_value, values_json,
          created_at, updated_at, is_archived
        FROM records
        WHERE id = ?
      ''',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return DatabaseRecord.fromRow(rows.single);
  }

  Future<bool> barcodeExistsForAnotherRecord({
    required String templateId,
    required String barcodeValue,
    required String recordId,
  }) async {
    final rows = await _executor.runSelect(
      '''
        SELECT id FROM records
        WHERE template_id = ? AND barcode_value = ? AND id != ? AND is_archived = 0
        LIMIT 1
      ''',
      <Object?>[templateId, barcodeValue, recordId],
    );
    return rows.isNotEmpty;
  }

  Future<void> updateRecord({
    required String id,
    required String reference,
    required String barcodeValue,
    required Map<String, String> values,
  }) {
    return _executor.runUpdate(
      '''
        UPDATE records
        SET record_reference = ?, barcode_value = ?, values_json = ?, updated_at = ?
        WHERE id = ?
      ''',
      <Object?>[
        reference,
        barcodeValue,
        jsonEncode(values),
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
  }

  Future<void> setRecordArchived({
    required String id,
    required bool isArchived,
  }) {
    return _executor.runUpdate(
      'UPDATE records SET is_archived = ?, updated_at = ? WHERE id = ?',
      <Object?>[
        isArchived ? 1 : 0,
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
  }

  Future<void> deleteRecord(String id) {
    return _executor.runDelete('DELETE FROM records WHERE id = ?', <Object?>[
      id,
    ]);
  }

  Future<void> saveImportBatch({
    required String batchId,
    required String templateId,
    required String fileName,
    required int totalRows,
    required int validRows,
    required int invalidRows,
    required List<DatabaseRecordInsert> records,
  }) async {
    final transaction = _executor.beginTransaction();
    try {
      await transaction.ensureOpen(_executorUser);
      final importedAt = DateTime.now().toUtc().toIso8601String();
      await transaction.runInsert(
        '''
          INSERT INTO import_batches (
            id, template_id, file_name, total_rows, valid_rows, invalid_rows,
            imported_at, status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        <Object?>[
          batchId,
          templateId,
          fileName,
          totalRows,
          validRows,
          invalidRows,
          importedAt,
          'completed',
        ],
      );
      for (final record in records) {
        await transaction.runInsert(
          '''
            INSERT INTO records (
              id, template_id, import_batch_id, record_reference,
              barcode_value, values_json, created_at, updated_at, is_archived
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
          ''',
          <Object?>[
            record.id,
            templateId,
            batchId,
            record.reference,
            record.barcodeValue,
            jsonEncode(record.values),
            importedAt,
            importedAt,
          ],
        );
      }
      await transaction.send();
    } catch (_) {
      await transaction.rollback();
      rethrow;
    }
  }
}

class _AppDatabaseExecutorUser implements QueryExecutorUser {
  const _AppDatabaseExecutorUser();

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

/// A structured record prepared by a feature repository for local storage.
class DatabaseRecordInsert {
  const DatabaseRecordInsert({
    required this.id,
    required this.reference,
    required this.barcodeValue,
    required this.values,
  });

  final String id;
  final String reference;
  final String barcodeValue;
  final Map<String, String> values;
}

/// A row returned from local record storage.
class DatabaseRecord {
  const DatabaseRecord({
    required this.id,
    required this.templateId,
    required this.reference,
    required this.barcodeValue,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
  });

  factory DatabaseRecord.fromRow(Map<String, Object?> row) {
    final decodedValues =
        jsonDecode(row['values_json'] as String) as Map<String, dynamic>;
    return DatabaseRecord(
      id: row['id'] as String,
      templateId: row['template_id'] as String,
      reference: row['record_reference'] as String,
      barcodeValue: row['barcode_value'] as String,
      values: decodedValues.map(
        (String key, dynamic value) => MapEntry(key, value?.toString() ?? ''),
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      isArchived: (row['is_archived'] as int) == 1,
    );
  }

  final String id;
  final String templateId;
  final String reference;
  final String barcodeValue;
  final Map<String, String> values;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
}
