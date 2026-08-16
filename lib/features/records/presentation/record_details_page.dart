import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/printing/printer_catalog.dart';
import '../../../core/printing/tspl_label_command_encoder.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../../../core/validation/import_validation_service.dart';
import '../../labels/domain/entities/label_layout.dart';
import '../../templates/domain/entities/import_template.dart';
import '../../templates/presentation/active_product_template_provider.dart';
import '../../printing/data/direct_label_print_service.dart';
import '../../printing/data/printer_profile_repository.dart';
import '../data/record_repository.dart';
import '../domain/entities/catalogue_record.dart';

class RecordDetailsPage extends ConsumerStatefulWidget {
  const RecordDetailsPage({
    required this.recordId,
    this.printerCatalog,
    super.key,
  });

  final String recordId;
  final PrinterCatalog? printerCatalog;

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
  bool _isPrinting = false;

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
      final template = await ref.read(activeProductTemplateProvider.future);
      if (!mounted) {
        return;
      }
      if (record != null) {
        for (final field in template.fields) {
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

  Future<void> _save(ImportTemplate template) async {
    final record = _record;
    if (record == null || !_formKey.currentState!.validate()) {
      return;
    }
    final values = <String, String>{
      for (final field in template.fields)
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
      template: template,
      headers: template.fields.map((field) => field.key).toList(),
      rows: <List<String>>[
        template.fields.map((field) => values[field.key] ?? '').toList(),
      ],
      columnMapping: <String, String?>{
        for (final field in template.fields) field.key: field.key,
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

  Future<void> _choosePrintQuantity() async {
    final record = _record;
    if (record == null) {
      return;
    }
    final copies = await showDialog<int>(
      context: context,
      builder: (BuildContext context) =>
          _PrintQuantityDialog(productName: record.name),
    );
    if (copies == null || !mounted) {
      return;
    }
    await _printLabels(record, copies);
  }

  Future<void> _printLabels(CatalogueRecord record, int copies) async {
    if (_isPrinting) {
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final database = await ref.read(appDatabaseProvider.future);
      await DirectLabelPrintService(
        printerProfiles: PrinterProfileRepository(database),
        printerCatalog: widget.printerCatalog ?? PrinterCatalog(),
      ).print(
        records: <CatalogueRecord>[record],
        recordCopies: <String, int>{record.id: copies},
        layout: productLabelLayout,
        primaryFieldKey: 'item_name',
        secondaryFieldKey: 'price',
      );
      _showMessage(
        'Sent $copies ${copies == 1 ? 'label' : 'labels'} to the default printer.',
      );
    } on Exception catch (error) {
      _showMessage(_printErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  String _printErrorMessage(Object error) {
    final technicalMessage = error.toString().toLowerCase();
    if (technicalMessage.contains('bluetooth_scan') ||
        technicalMessage.contains('bluetooth_connect') ||
        technicalMessage.contains('nearby devices permission')) {
      return 'Allow Nearby devices permission to use paired Bluetooth printers, then try again.';
    }
    return switch (error) {
      DirectLabelPrintException exception => exception.message,
      TsplPrintingException exception => exception.message,
      PlatformException exception =>
        exception.message ?? 'The default printer could not be reached.',
      _ => 'The labels could not be prepared for printing. Try again.',
    };
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
                style: FilledButton.styleFrom(
                  backgroundColor: destructive
                      ? Theme.of(context).colorScheme.error
                      : null,
                  minimumSize: Size.zero,
                ),
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
    final templateState = ref.watch(activeProductTemplateProvider);
    if (templateState.isLoading) {
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
    if (templateState.hasError) {
      return const AppPageContent(
        children: <Widget>[
          PageHeading(
            eyebrow: 'Catalogue',
            title: 'Template unavailable',
            description: 'The field requirements could not be loaded.',
          ),
        ],
      );
    }
    final template = templateState.requireValue;
    return Stack(
      children: <Widget>[
        AppPageContent(
          children: <Widget>[
            PageHeading(
              eyebrow: 'Catalogue record',
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      for (final field in template.fields) ...<Widget>[
                        TextFormField(
                          controller: _controllers[field.key],
                          enabled: !_isSaving,
                          keyboardType: switch (field.dataType) {
                            FieldDataType.integer || FieldDataType.decimal =>
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : () => _save(template),
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
            const SizedBox(height: 72),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            key: const Key('record-print-button'),
            heroTag: 'record-print-${record.id}',
            tooltip: 'Print ${record.name}',
            onPressed: _isPrinting ? null : _choosePrintQuantity,
            child: _isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.printer),
          ),
        ),
      ],
    );
  }
}

class _PrintQuantityDialog extends StatefulWidget {
  const _PrintQuantityDialog({required this.productName});

  final String productName;

  @override
  State<_PrintQuantityDialog> createState() => _PrintQuantityDialogState();
}

class _PrintQuantityDialogState extends State<_PrintQuantityDialog> {
  int _copies = 1;
  late final TextEditingController _copiesController;
  String? _quantityError;

  @override
  void initState() {
    super.initState();
    _copiesController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _copiesController.dispose();
    super.dispose();
  }

  void _setCopies(int copies) {
    setState(() {
      _copies = copies;
      _copiesController.text = '$copies';
      _quantityError = null;
    });
  }

  void _continueToPrint() {
    final copies = int.tryParse(_copiesController.text);
    if (copies == null || copies < 1) {
      setState(() => _quantityError = 'Enter at least 1 label.');
      return;
    }
    Navigator.pop(context, copies);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Print labels',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedInk),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Label quantity',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      IconButton.outlined(
                        key: const Key('print-quantity-decrease'),
                        tooltip: 'Decrease quantity',
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(48),
                          maximumSize: const Size.square(48),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                        onPressed: _copies > 1
                            ? () => _setCopies(_copies - 1)
                            : null,
                        icon: const Icon(LucideIcons.minus, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: const Key('print-quantity-input'),
                          controller: _copiesController,
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: '1',
                            errorText: _quantityError,
                          ),
                          onChanged: (String value) {
                            final copies = int.tryParse(value);
                            if (copies != null && copies > 0) {
                              setState(() {
                                _copies = copies;
                                _quantityError = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        key: const Key('print-quantity-increase'),
                        tooltip: 'Increase quantity',
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(48),
                          maximumSize: const Size.square(48),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                        onPressed: () => _setCopies(_copies + 1),
                        icon: const Icon(LucideIcons.plus, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _continueToPrint,
                      child: const Text('Print labels'),
                    ),
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
