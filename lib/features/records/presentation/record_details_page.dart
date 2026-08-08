import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../../../core/validation/import_validation_service.dart';
import '../../templates/data/builtin_templates.dart';
import '../../templates/domain/entities/import_template.dart';
import '../data/record_repository.dart';
import '../domain/entities/catalogue_record.dart';

class RecordDetailsPage extends ConsumerStatefulWidget {
  const RecordDetailsPage({required this.recordId, super.key});

  final String recordId;

  @override
  ConsumerState<RecordDetailsPage> createState() => _RecordDetailsPageState();
}

class _RecordDetailsPageState extends ConsumerState<RecordDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _validator = const ImportValidationService();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  CatalogueRecord? _record;
  Object? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecord());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<RecordRepository> _repository() async {
    final database = await ref.read(appDatabaseProvider.future);
    return RecordRepository(database);
  }

  Future<void> _loadRecord() async {
    try {
      final record = await (await _repository()).getById(widget.recordId);
      if (!mounted) {
        return;
      }
      if (record != null) {
        for (final field in productTemplate.fields) {
          _controllers[field.key] = TextEditingController(
            text: record.values[field.key] ?? '',
          );
        }
      }
      setState(() => _record = record);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    final record = _record;
    if (record == null || !_formKey.currentState!.validate()) {
      return;
    }
    final values = <String, String>{
      for (final field in productTemplate.fields)
        field.key: _controllers[field.key]!.text.trim(),
    };
    final updated = record.copyWith(
      reference: values['item_code'],
      barcodeValue: values['barcode'],
      values: values,
    );
    final repository = await _repository();
    final hasDuplicate = await repository.hasDuplicateBarcode(updated);
    final validation = _validator.validate(
      template: productTemplate,
      headers: productTemplate.fields.map((field) => field.key).toList(),
      rows: <List<String>>[
        productTemplate.fields.map((field) => values[field.key] ?? '').toList(),
      ],
      columnMapping: <String, String?>{
        for (final field in productTemplate.fields) field.key: field.key,
      },
      existingBarcodeValues: hasDuplicate
          ? <String>{updated.barcodeValue}
          : const <String>{},
    );
    if (!validation.rows.single.isValid) {
      _showMessage(
        validation.rows.single.issues.map((issue) => issue.message).join('\n'),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await repository.save(updated);
      if (mounted) {
        _showMessage('Record saved.');
        context.go('/records');
      }
    } on Exception catch (error) {
      _showMessage('Could not save record: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _setArchived(bool archived) async {
    final record = _record;
    if (record == null) {
      return;
    }
    final approved = await _confirm(
      title: archived ? 'Archive record?' : 'Restore record?',
      message: archived
          ? 'Archived records stay on this device but are excluded from active catalogue lists.'
          : 'This record will return to the active catalogue.',
      actionLabel: archived ? 'Archive' : 'Restore',
    );
    if (!approved) {
      return;
    }
    try {
      await (await _repository()).archive(record, archived: archived);
      if (mounted) {
        _showMessage(archived ? 'Record archived.' : 'Record restored.');
        context.go('/records');
      }
    } on Exception catch (error) {
      _showMessage('Could not update record: $error');
    }
  }

  Future<void> _delete() async {
    final record = _record;
    if (record == null) {
      return;
    }
    final approved = await _confirm(
      title: 'Delete record?',
      message: 'This permanently removes the record from this device.',
      actionLabel: 'Delete',
      destructive: true,
    );
    if (!approved) {
      return;
    }
    try {
      await (await _repository()).delete(record);
      if (mounted) {
        _showMessage('Record deleted.');
        context.go('/records');
      }
    } on Exception catch (error) {
      _showMessage('Could not delete record: $error');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
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
    if (_isLoading) {
      return const AppPageContent(
        children: <Widget>[
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }
    if (_loadError != null) {
      return AppPageContent(
        children: <Widget>[
          const PageHeading(
            eyebrow: 'Catalogue',
            title: 'Record unavailable',
            description: 'The local record could not be opened.',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.go('/records'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to records'),
          ),
        ],
      );
    }
    final record = _record;
    if (record == null) {
      return AppPageContent(
        children: <Widget>[
          const PageHeading(
            eyebrow: 'Catalogue',
            title: 'Record not found',
            description: 'It may have already been deleted.',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.go('/records'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to records'),
          ),
        ],
      );
    }
    return AppPageContent(
      children: <Widget>[
        PageHeading(
          eyebrow: record.isArchived ? 'Archived record' : 'Catalogue record',
          title: record.name,
          description:
              'Review the stored fields and keep barcode data valid and unique.',
        ),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Record details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final field in productTemplate.fields) ...<Widget>[
                    TextFormField(
                      controller: _controllers[field.key],
                      enabled: !record.isArchived && !_isSaving,
                      keyboardType: switch (field.dataType) {
                        FieldDataType.integer || FieldDataType.decimal =>
                          const TextInputType.numberWithOptions(decimal: true),
                        _ => TextInputType.text,
                      },
                      decoration: InputDecoration(
                        labelText:
                            '${field.displayName}${field.required ? ' *' : ''}',
                        helperText: field.example == null
                            ? null
                            : 'Example: ${field.example}',
                      ),
                      validator: (String? value) =>
                          field.required &&
                              (value == null || value.trim().isEmpty)
                          ? '${field.displayName} is required.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!record.isArchived)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save changes'),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _setArchived(!record.isArchived),
            icon: Icon(
              record.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
            label: Text(
              record.isArchived ? 'Restore record' : 'Archive record',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _delete,
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              'Delete record',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
