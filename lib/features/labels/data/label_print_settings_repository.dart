import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../templates/data/builtin_templates.dart';
import '../domain/entities/label_layout.dart';

typedef LabelPrintSettings = ({
  LabelLayout layout,
  String primaryFieldKey,
  String secondaryFieldKey,
});

class LabelPrintSettingsRepository {
  LabelPrintSettingsRepository(this._database);

  final AppDatabase _database;
  static const _key = 'default_label_print_settings';

  Future<LabelPrintSettings> load() async {
    final value = await _database.metadataValue(_key);
    Map<String, dynamic> settings = {};
    if (value != null) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) settings = decoded;
      } on FormatException {
        // Use the built-in defaults for invalid stored settings.
      }
    }
    final keys = productTemplate.fields.map((field) => field.key).toSet();
    final primary = settings['primary'];
    final secondary = settings['secondary'];
    return (
      layout: productLabelLayoutForId(
        settings['layout'] is String ? settings['layout'] as String : null,
      ),
      primaryFieldKey: primary is String && keys.contains(primary)
          ? primary
          : 'item_name',
      secondaryFieldKey:
          secondary is String && (secondary.isEmpty || keys.contains(secondary))
          ? secondary
          : 'price',
    );
  }

  Future<void> save(LabelPrintSettings settings) => _database.saveMetadata(
    key: _key,
    value: jsonEncode({
      'layout': settings.layout.id,
      'primary': settings.primaryFieldKey,
      'secondary': settings.secondaryFieldKey,
    }),
  );
}
