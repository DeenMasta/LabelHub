import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../../../core/validation/import_validation_service.dart';
import '../../templates/domain/entities/import_template.dart';
import '../../templates/presentation/active_product_template_provider.dart';
import '../data/import_parser.dart';
import '../data/import_repository.dart';

class ImportsPage extends ConsumerStatefulWidget {
  const ImportsPage({super.key});

  @override
  ConsumerState<ImportsPage> createState() => _ImportsPageState();
}

class _ImportsPageState extends ConsumerState<ImportsPage> {
  final _parser = const ImportParser();
  final _validator = const ImportValidationService();
  ImportDocument? _document;
  ImportValidationResult? _validation;
  String? _fileName;
  Map<String, String?> _mapping = <String, String?>{};
  bool _isPicking = false;
  bool _isSaving = false;

  Future<void> _chooseFile(ImportTemplate template) async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['csv', 'xlsx'],
        withData: true,
      );
      if (!mounted || result == null) {
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('LabelHub could not read this file.');
      }
      
      final ImportDocument document;
      if (file.extension?.toLowerCase() == 'xlsx') {
        document = _parser.parseExcel(bytes);
      } else {
        document = _parser.parseCsv(utf8.decode(bytes));
      }
      
      setState(() {
        _document = document;
        _fileName = file.name;
        _validation = null;
        _mapping = <String, String?>{
          for (final field in template.fields)
            field.key: document.headers.contains(field.displayName)
                ? field.displayName
                : (document.headers.contains(field.key) ? field.key : null),
        };
      });
    } on FormatException catch (error) {
      _showMessage(error.message);
    } on Exception catch (error) {
      _showMessage('Could not open file: $error');
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _validate(ImportTemplate template) async {
    final document = _document;
    if (document == null) {
      return;
    }
    try {
      final database = await ref.read(appDatabaseProvider.future);
      final repository = ImportRepository(database);
      final existingBarcodes = await repository.existingBarcodes(template);
      final validation = _validator.validate(
        template: template,
        headers: document.headers,
        rows: document.rows,
        columnMapping: _mapping,
        existingBarcodeValues: existingBarcodes,
      );
      if (mounted) {
        setState(() => _validation = validation);
      }
    } on Exception catch (error) {
      _showMessage('Could not validate this import: $error');
    }
  }

  Future<void> _saveValidRows(ImportTemplate template) async {
    final validation = _validation;
    if (validation == null ||
        validation.validRowCount == 0 ||
        _fileName == null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final database = await ref.read(appDatabaseProvider.future);
      await ImportRepository(database).saveValidRows(
        template: template,
        fileName: _fileName!,
        validation: validation,
      );
      if (!mounted) {
        return;
      }
      _showMessage('${validation.validRowCount} valid rows were imported.');
      setState(() {
        _document = null;
        _fileName = null;
        _mapping = <String, String?>{};
        _validation = null;
      });
    } on Exception catch (error) {
      _showMessage('Could not save the import: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final templateState = ref.watch(activeProductTemplateProvider);
    final template = switch (templateState) {
      AsyncData<ImportTemplate>(:final value) => value,
      _ => null,
    };
    return AppPageContent(
      children: <Widget>[
        const PageHeading(
          eyebrow: 'Product catalogue',
          title: 'Import data',
          description:
              'Bring in a product spreadsheet, check every row, then add only valid records to your catalogue.',
        ),
        const SizedBox(height: 20),
        if (template == null)
          _TemplateLoadingOrError(hasError: templateState.hasError)
        else ...<Widget>[
          _ImportWorkflowSteps(
            hasFile: document != null,
            hasValidation: _validation != null,
          ),
          const SizedBox(height: 20),
          _TemplateSummaryCard(template: template),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isPicking ? null : () => _chooseFile(template),
              icon: _isPicking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open_outlined),
              label: Text(
                document == null ? 'Choose spreadsheet' : 'Choose another spreadsheet',
              ),
            ),
          ),
          if (document != null) ...<Widget>[
            const SizedBox(height: 20),
            _ColumnMappingCard(
              headers: document.headers,
              template: template,
              mapping: _mapping,
              onChanged: (String fieldKey, String? header) {
                setState(() {
                  _mapping = <String, String?>{..._mapping, fieldKey: header};
                  _validation = null;
                });
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _validate(template),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text('Validate ${document.rows.length} rows'),
            ),
          ],
          if (_validation case final validation?) ...<Widget>[
            const SizedBox(height: 20),
            _ValidationSummaryCard(validation: validation),
            if (validation.invalidRowCount > 0) ...<Widget>[
              const SizedBox(height: 12),
              _ValidationIssueList(validation: validation),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving || validation.validRowCount == 0
                  ? null
                  : () => _saveValidRows(template),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text('Import ${validation.validRowCount} valid rows'),
            ),
          ],
        ],
      ],
    );
  }
}

class _TemplateLoadingOrError extends StatelessWidget {
  const _TemplateLoadingOrError({required this.hasError});

  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Template settings could not be loaded.'),
        ),
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _TemplateSummaryCard extends StatelessWidget {
  const _TemplateSummaryCard({required this.template});

  final ImportTemplate template;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    template.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Required: ${template.fields.where((TemplateField field) => field.required).map((TemplateField field) => field.key).join(', ')}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportWorkflowSteps extends StatelessWidget {
  const _ImportWorkflowSteps({
    required this.hasFile,
    required this.hasValidation,
  });

  final bool hasFile;
  final bool hasValidation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ImportWorkflowStep(
            number: '1',
            label: 'Choose file',
            complete: hasFile,
            active: !hasFile,
          ),
        ),
        const _WorkflowConnector(),
        Expanded(
          child: _ImportWorkflowStep(
            number: '2',
            label: 'Map columns',
            complete: hasValidation,
            active: hasFile && !hasValidation,
          ),
        ),
        const _WorkflowConnector(),
        Expanded(
          child: _ImportWorkflowStep(
            number: '3',
            label: 'Review & save',
            active: hasValidation,
          ),
        ),
      ],
    );
  }
}

class _ImportWorkflowStep extends StatelessWidget {
  const _ImportWorkflowStep({
    required this.number,
    required this.label,
    this.complete = false,
    this.active = false,
  });

  final String number;
  final String label;
  final bool complete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active || complete
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF8A9690);
    return Column(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: complete
                ? Theme.of(context).colorScheme.primary
                : active
                ? AppTheme.paleBlueSurface
                : Colors.white,
            border: Border.all(color: color),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: complete
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      number,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: active || complete ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _WorkflowConnector extends StatelessWidget {
  const _WorkflowConnector();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      child: Divider(color: Color(0xFFE1E8E4), thickness: 1),
    );
  }
}

class _ColumnMappingCard extends StatelessWidget {
  const _ColumnMappingCard({
    required this.headers,
    required this.template,
    required this.mapping,
    required this.onChanged,
  });

  final List<String> headers;
  final ImportTemplate template;
  final Map<String, String?> mapping;
  final void Function(String fieldKey, String? header) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Map columns',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Match each template field to a column in your file.'),
            const SizedBox(height: 12),
            for (final field in template.fields) ...<Widget>[
              DropdownButtonFormField<String>(
                initialValue: mapping[field.key],
                isExpanded: true,
                decoration: InputDecoration(
                  labelText:
                      '${field.displayName}${field.required ? ' *' : ''}',
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Not mapped'),
                  ),
                  for (final header in headers)
                    DropdownMenuItem<String>(
                      value: header,
                      child: Text(header),
                    ),
                ],
                onChanged: (String? header) => onChanged(field.key, header),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValidationSummaryCard extends StatelessWidget {
  const _ValidationSummaryCard({required this.validation});

  final ImportValidationResult validation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _SummaryMetric(
                label: 'Total',
                value: validation.rows.length.toString(),
              ),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Valid',
                value: validation.validRowCount.toString(),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Invalid',
                value: validation.invalidRowCount.toString(),
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ValidationIssueList extends StatelessWidget {
  const _ValidationIssueList({required this.validation});

  final ImportValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final issues = validation.rows
        .expand((ValidatedImportRow row) => row.issues)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Rows needing correction',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final issue in issues.take(20))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Row ${issue.rowNumber}: ${issue.message}'),
              ),
            if (issues.length > 20)
              Text('${issues.length - 20} more issues in this file.'),
          ],
        ),
      ),
    );
  }
}
