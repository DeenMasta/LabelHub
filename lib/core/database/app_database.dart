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

  static Future<AppDatabase> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final databaseFile = File(path.join(directory.path, 'labelhub.sqlite'));
    final database = AppDatabase._(
      NativeDatabase.createInBackground(databaseFile),
    );
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
}
