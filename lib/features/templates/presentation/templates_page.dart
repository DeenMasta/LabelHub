import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../data/template_csv_exporter.dart';
import '../data/template_settings_repository.dart';
import '../domain/entities/import_template.dart';
import 'active_product_template_provider.dart';

class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  final _csvExporter = const TemplateCsvExporter();
  var _isExporting = false;
  var _isSavingRequirements = false;

  Future<void> _exportCsvTemplate(ImportTemplate template) async {
    setState(() => _isExporting = true);
    try {
      final savedPath = await _csvExporter.export(template);
      if (!mounted || savedPath == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blank CSV template saved to $savedPath')),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export CSV: $error')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _setRequired(
    ImportTemplate template,
    TemplateField field,
    bool required,
  ) async {
    if (field.key == template.barcodeFieldKey) {
      return;
    }
    setState(() => _isSavingRequirements = true);
    try {
      final database = await ref.read(appDatabaseProvider.future);
      final requiredKeys = template.fields
          .where((TemplateField value) => value.required)
          .map((TemplateField value) => value.key)
          .toSet();
      if (required) {
        requiredKeys.add(field.key);
      } else {
        requiredKeys.remove(field.key);
      }
      await TemplateSettingsRepository(database).saveRequiredFieldKeys(
        template: template,
        requiredFieldKeys: requiredKeys,
      );
      ref.invalidate(activeProductTemplateProvider);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save required fields: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingRequirements = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = ref.watch(activeProductTemplateProvider);
    return AppPageContent(
      children: <Widget>[
        const PageHeading(
          eyebrow: 'Import setup',
          title: 'Templates',
          description:
              'Choose the structure that LabelHub uses to check every row before it is added to your records.',
        ),
        const SizedBox(height: 24),
        template.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, _) => const _TemplateSettingsLoadError(),
          data: (ImportTemplate value) => _TemplateOverviewCard(
            template: value,
            isExporting: _isExporting,
            isSavingRequirements: _isSavingRequirements,
            onExport: () => _exportCsvTemplate(value),
            onImport: () => context.go('/imports'),
            onRequiredChanged: (TemplateField field, bool required) =>
                _setRequired(value, field, required),
          ),
        ),
      ],
    );
  }
}

class _TemplateOverviewCard extends StatelessWidget {
  const _TemplateOverviewCard({
    required this.template,
    required this.isExporting,
    required this.isSavingRequirements,
    required this.onExport,
    required this.onImport,
    required this.onRequiredChanged,
  });

  final ImportTemplate template;
  final bool isExporting;
  final bool isSavingRequirements;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final void Function(TemplateField field, bool required) onRequiredChanged;

  @override
  Widget build(BuildContext context) {
    final requiredFields = template.fields
        .where((TemplateField field) => field.required)
        .length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            color: AppTheme.paleBlueSurface,
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _TemplateIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        template.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(template.description),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _TemplateStat(
                      value: '$requiredFields',
                      label: 'required fields',
                    ),
                    _TemplateStat(
                      value: '${template.fields.length}',
                      label: 'total columns',
                    ),
                    const _SystemTemplateBadge(),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'CSV columns',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _TemplateFieldList(
                  fields: template.fields,
                  barcodeFieldKey: template.barcodeFieldKey,
                  isSavingRequirements: isSavingRequirements,
                  onRequiredChanged: onRequiredChanged,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import product CSV'),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: isExporting ? null : onExport,
                    icon: isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: const Text('Download blank CSV'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateIcon extends StatelessWidget {
  const _TemplateIcon();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFF121C2A),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(Icons.inventory_2_outlined, color: Colors.white),
      ),
    );
  }
}

class _TemplateStat extends StatelessWidget {
  const _TemplateStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SystemTemplateBadge extends StatelessWidget {
  const _SystemTemplateBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFEEF2F0),
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'Built in',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TemplateFieldList extends StatelessWidget {
  const _TemplateFieldList({
    required this.fields,
    required this.barcodeFieldKey,
    required this.isSavingRequirements,
    required this.onRequiredChanged,
  });

  final List<TemplateField> fields;
  final String barcodeFieldKey;
  final bool isSavingRequirements;
  final void Function(TemplateField field, bool required) onRequiredChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8F6),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: <Widget>[
          for (var index = 0; index < fields.length; index++)
            _TemplateFieldRow(
              field: fields[index],
              showDivider: index < fields.length - 1,
              isBarcodeField: fields[index].key == barcodeFieldKey,
              isSavingRequirements: isSavingRequirements,
              onRequiredChanged: onRequiredChanged,
            ),
        ],
      ),
    );
  }
}

class _TemplateFieldRow extends StatelessWidget {
  const _TemplateFieldRow({
    required this.field,
    required this.showDivider,
    required this.isBarcodeField,
    required this.isSavingRequirements,
    required this.onRequiredChanged,
  });

  final TemplateField field;
  final bool showDivider;
  final bool isBarcodeField;
  final bool isSavingRequirements;
  final void Function(TemplateField field, bool required) onRequiredChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFE1E8E4)))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: CheckboxListTile(
          value: field.required,
          onChanged: isBarcodeField || isSavingRequirements
              ? null
              : (bool? required) => onRequiredChanged(field, required ?? false),
          title: Text(
            field.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            isBarcodeField
                ? 'Required for barcode labels'
                : field.example == null
                ? 'Tick to require this field in every imported row.'
                : 'Example: ${field.example}',
          ),
          secondary: Text(
            field.required ? 'Required' : 'Optional',
            style: TextStyle(
              color: field.required
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF66736C),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateSettingsLoadError extends StatelessWidget {
  const _TemplateSettingsLoadError();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('Template settings could not be loaded.'),
      ),
    );
  }
}
