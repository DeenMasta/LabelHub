import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/entities/import_template.dart';

/// Persists user-selected required fields for the built-in product template.
class TemplateSettingsRepository {
  TemplateSettingsRepository(this._database);

  static const _productRequiredFieldsKey = 'product_template_required_fields';

  final AppDatabase _database;

  Future<ImportTemplate> loadProductTemplate(ImportTemplate template) async {
    final storedValue = await _database.metadataValue(
      _productRequiredFieldsKey,
    );
    if (storedValue == null) {
      return template;
    }
    try {
      final decoded = jsonDecode(storedValue) as List<dynamic>;
      final availableKeys = template.fields
          .map((TemplateField field) => field.key)
          .toSet();
      final requiredKeys =
          decoded.whereType<String>().where(availableKeys.contains).toSet()
            ..add(template.barcodeFieldKey);
      return template.withRequiredFieldKeys(requiredKeys);
    } on FormatException {
      return template;
    }
  }

  Future<void> saveRequiredFieldKeys({
    required ImportTemplate template,
    required Set<String> requiredFieldKeys,
  }) {
    final supportedKeys = template.fields
        .map((TemplateField field) => field.key)
        .toSet();
    final values = <String>{
      ...requiredFieldKeys.where(supportedKeys.contains),
      template.barcodeFieldKey,
    }.toList()..sort();
    return _database.saveMetadata(
      key: _productRequiredFieldsKey,
      value: jsonEncode(values),
    );
  }
}
