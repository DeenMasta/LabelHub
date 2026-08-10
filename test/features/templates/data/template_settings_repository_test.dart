import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/features/templates/data/builtin_templates.dart';
import 'package:labelhub/features/templates/data/template_settings_repository.dart';

void main() {
  late AppDatabase database;
  late TemplateSettingsRepository repository;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
    repository = TemplateSettingsRepository(database);
  });

  tearDown(() => database.close());

  test(
    'saves configurable required fields while retaining the barcode rule',
    () async {
      await repository.saveRequiredFieldKeys(
        template: productTemplate,
        requiredFieldKeys: const <String>{'item_name'},
      );

      final template = await repository.loadProductTemplate(productTemplate);

      expect(
        template.fields
            .singleWhere((field) => field.key == 'item_code')
            .required,
        isFalse,
      );
      expect(
        template.fields
            .singleWhere((field) => field.key == 'item_name')
            .required,
        isTrue,
      );
      expect(
        template.fields.singleWhere((field) => field.key == 'barcode').required,
        isTrue,
      );
    },
  );
}
