import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

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
        SnackBar(
          content: Text('Blank CSV template saved to $savedPath'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(savedPath),
          ),
        ),
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
          eyebrow: 'Product catalogue',
          title: 'Product import template',
          description:
              'Set the fields you collect once, then import product data with confidence.',
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
          data: (ImportTemplate value) => _TemplateWorkspace(
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

class _TemplateWorkspace extends StatelessWidget {
  const _TemplateWorkspace({
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
    return Column(
      children: <Widget>[
        _ActiveTemplateCard(
          template: template,
          isExporting: isExporting,
          onExport: onExport,
          onImport: onImport,
        ),
        const SizedBox(height: 16),
        const _ImportGuideCard(),
        const SizedBox(height: 16),
        _TemplateFieldsCard(
          template: template,
          isSavingRequirements: isSavingRequirements,
          onRequiredChanged: onRequiredChanged,
        ),
      ],
    );
  }
}

class _ActiveTemplateCard extends StatelessWidget {
  const _ActiveTemplateCard({
    required this.template,
    required this.isExporting,
    required this.onExport,
    required this.onImport,
  });

  final ImportTemplate template;
  final bool isExporting;
  final VoidCallback onExport;
  final VoidCallback onImport;

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
                      const _ActiveTemplateBadge(),
                      const SizedBox(height: 10),
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
                Text(
                  'Your import setup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _TemplateMetrics(
                  totalFields: template.fields.length,
                  requiredFields: requiredFields,
                ),
                const SizedBox(height: 20),
                _TemplateActionButtons(
                  isExporting: isExporting,
                  onExport: onExport,
                  onImport: onImport,
                ),
                const SizedBox(height: 12),
                Text(
                  'Import CSV or XLSX files. Every row is checked before products are added.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5F6B65),
                    height: 1.4,
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

class _ActiveTemplateBadge extends StatelessWidget {
  const _ActiveTemplateBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.verified_outlined, size: 14, color: AppTheme.primary),
            SizedBox(width: 6),
            Text(
              'ACTIVE',
              style: TextStyle(
                color: AppTheme.navy,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
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
        color: AppTheme.navy,
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

class _TemplateMetrics extends StatelessWidget {
  const _TemplateMetrics({
    required this.totalFields,
    required this.requiredFields,
  });

  final int totalFields;
  final int requiredFields;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final metrics = <Widget>[
          _TemplateMetric(value: '$totalFields', label: 'Columns'),
          _TemplateMetric(value: '$requiredFields', label: 'Required'),
          const _TemplateMetric(value: 'Code 128', label: 'Barcode'),
        ];
        if (constraints.maxWidth >= 520) {
          return Row(
            children: <Widget>[
              for (var index = 0; index < metrics.length; index++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < metrics.length - 1 ? 12 : 0,
                    ),
                    child: metrics[index],
                  ),
                ),
            ],
          );
        }
        return Column(
          children: <Widget>[
            for (var index = 0; index < metrics.length; index++) ...<Widget>[
              metrics[index],
              if (index < metrics.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _TemplateMetric extends StatelessWidget {
  const _TemplateMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TemplateActionButtons extends StatelessWidget {
  const _TemplateActionButtons({
    required this.isExporting,
    required this.onExport,
    required this.onImport,
  });

  final bool isExporting;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final importButton = FilledButton.icon(
      onPressed: onImport,
      icon: const Icon(Icons.file_upload_outlined),
      label: const Text('Import products'),
    );
    final exportButton = OutlinedButton.icon(
      onPressed: isExporting ? null : onExport,
      icon: isExporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined),
      label: const Text('Download CSV'),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            children: <Widget>[
              Expanded(child: importButton),
              const SizedBox(width: 12),
              Expanded(child: exportButton),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            importButton,
            const SizedBox(height: 8),
            exportButton,
          ],
        );
      },
    );
  }
}

class _ImportGuideCard extends StatelessWidget {
  const _ImportGuideCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'How imports work',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'A short review step keeps your product catalogue clean.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5F6B65)),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const steps = <_ImportGuideStepData>[
                  _ImportGuideStepData(
                    number: '1',
                    title: 'Prepare your file',
                    description:
                        'Use the CSV download or your own spreadsheet.',
                  ),
                  _ImportGuideStepData(
                    number: '2',
                    title: 'Match your columns',
                    description:
                        'Check that each spreadsheet column is mapped.',
                  ),
                  _ImportGuideStepData(
                    number: '3',
                    title: 'Review and import',
                    description:
                        'Only valid product rows are added to LabelHub.',
                  ),
                ];
                if (constraints.maxWidth >= 760) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (var index = 0; index < steps.length; index++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index < steps.length - 1 ? 16 : 0,
                            ),
                            child: _ImportGuideStep(data: steps[index]),
                          ),
                        ),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < steps.length;
                      index++
                    ) ...<Widget>[
                      _ImportGuideStep(data: steps[index]),
                      if (index < steps.length - 1) const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportGuideStepData {
  const _ImportGuideStepData({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;
}

class _ImportGuideStep extends StatelessWidget {
  const _ImportGuideStep({required this.data});

  final _ImportGuideStepData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppTheme.paleBlue,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Text(
                data.number,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                data.title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                data.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5F6B65),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplateFieldsCard extends StatelessWidget {
  const _TemplateFieldsCard({
    required this.template,
    required this.isSavingRequirements,
    required this.onRequiredChanged,
  });

  final ImportTemplate template;
  final bool isSavingRequirements;
  final void Function(TemplateField field, bool required) onRequiredChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.paleBlue,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.rule_folder_outlined,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Fields and validation',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Turn on a field to require it in every imported row. Barcode is always required for label printing.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TemplateFieldList(
              fields: template.fields,
              barcodeFieldKey: template.barcodeFieldKey,
              isSavingRequirements: isSavingRequirements,
              onRequiredChanged: onRequiredChanged,
            ),
          ],
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
      color: AppTheme.canvas,
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
    final detail = isBarcodeField
        ? 'Always required for barcode labels'
        : field.example == null
        ? 'Require this field in every imported row'
        : 'Example: ${field.example}';
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppTheme.border))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  isBarcodeField
                      ? Icons.qr_code_2_outlined
                      : Icons.short_text_rounded,
                  size: 20,
                  color: AppTheme.navy,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          field.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FieldTypeBadge(dataType: field.dataType),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5F6B65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isBarcodeField)
              const _LockedRequiredField()
            else
              Semantics(
                label: 'Require ${field.displayName}',
                toggled: field.required,
                child: Switch(
                  value: field.required,
                  onChanged: isSavingRequirements
                      ? null
                      : (bool required) => onRequiredChanged(field, required),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FieldTypeBadge extends StatelessWidget {
  const _FieldTypeBadge({required this.dataType});

  final FieldDataType dataType;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.paleBlueSurface,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          switch (dataType) {
            FieldDataType.text => 'Text',
            FieldDataType.integer => 'Whole number',
            FieldDataType.decimal => 'Decimal',
            FieldDataType.date => 'Date',
          },
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LockedRequiredField extends StatelessWidget {
  const _LockedRequiredField();

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: 'Barcode is required to create barcode labels',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(Icons.lock_outline, size: 20, color: AppTheme.navy),
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
