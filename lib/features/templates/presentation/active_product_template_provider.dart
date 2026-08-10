import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/builtin_templates.dart';
import '../data/template_settings_repository.dart';
import '../domain/entities/import_template.dart';

/// The built-in product template with the user's saved required-field choices.
final activeProductTemplateProvider = FutureProvider<ImportTemplate>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  return TemplateSettingsRepository(
    database,
  ).loadProductTemplate(productTemplate);
});
