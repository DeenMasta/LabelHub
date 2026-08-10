import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../../records/data/record_repository.dart';
import '../../records/domain/entities/catalogue_record.dart';
import '../../templates/data/builtin_templates.dart';
import '../../templates/domain/entities/import_template.dart';
import '../data/barcode_preview_service.dart';
import '../domain/entities/barcode_request.dart';
import '../domain/entities/label_layout.dart';
import 'widgets/label_layout_selector.dart';
import 'widgets/record_selector_card.dart';

class LabelsPage extends ConsumerStatefulWidget {
  const LabelsPage({super.key});

  @override
  ConsumerState<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends ConsumerState<LabelsPage> {
  static const _barcodeService = BarcodePreviewService();

  final Set<String> _selectedRecordIds = <String>{};
  List<CatalogueRecord> _records = const <CatalogueRecord>[];
  BarcodePreview? _barcodePreview;
  Object? _loadError;
  String _primaryFieldKey = 'item_name';
  String _secondaryFieldKey = 'price';
  LabelLayout _layout = productLabelLayout;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  CatalogueRecord? get _previewRecord {
    for (final record in _records) {
      if (_selectedRecordIds.contains(record.id)) {
        return record;
      }
    }
    return null;
  }

  Future<void> _loadRecords() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final database = await ref.read(appDatabaseProvider.future);
      final records = (await RecordRepository(
        database,
      ).list()).where((CatalogueRecord record) => !record.isArchived).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        if (records.length == 1) {
          _selectedRecordIds.add(records.single.id);
        }
        _refreshBarcodePreview();
      });
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

  void _toggleRecord(CatalogueRecord record, bool selected) {
    setState(() {
      if (selected) {
        _selectedRecordIds.add(record.id);
      } else {
        _selectedRecordIds.remove(record.id);
      }
      _refreshBarcodePreview();
    });
  }

  void _refreshBarcodePreview() {
    final record = _previewRecord;
    if (record == null) {
      _barcodePreview = null;
      return;
    }
    _barcodePreview = _barcodeService.create(
      BarcodeRequest(
        value: record.barcodeValue,
        format: productTemplate.barcodeFormat,
        widthMm: _layout.barcodeWidthMm,
        heightMm: _layout.barcodeHeightMm,
        showText: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageContent(
      children: <Widget>[
        const PageHeading(
          eyebrow: 'Output',
          title: 'Label preview',
          description:
              'Select active records, check the fixed product layout, and confirm barcode data before printing.',
        ),
        const SizedBox(height: 20),
        _LabelLayoutSummary(layout: _layout),
        const SizedBox(height: 12),
        LabelLayoutSelector(
          selectedLayout: _layout,
          onChanged: (LabelLayout? layout) {
            if (layout != null) {
              setState(() {
                _layout = layout;
                _refreshBarcodePreview();
              });
            }
          },
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const _LabelsLoadingPanel()
        else if (_loadError != null)
          _LabelsLoadError(onRetry: _loadRecords)
        else if (_records.isEmpty)
          _NoRecordsForLabels(onImport: () => context.go('/imports'))
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final selector = RecordSelectorCard(
                records: _records,
                selectedRecordIds: _selectedRecordIds,
                onChanged: _toggleRecord,
              );
              final preview = _LabelPreviewPanel(
                record: _previewRecord,
                selectedCount: _selectedRecordIds.length,
                primaryFieldKey: _primaryFieldKey,
                secondaryFieldKey: _secondaryFieldKey,
                layout: _layout,
                barcodePreview: _barcodePreview,
                onPrimaryFieldChanged: (String? key) {
                  if (key != null) {
                    setState(() => _primaryFieldKey = key);
                  }
                },
                onSecondaryFieldChanged: (String? key) {
                  if (key != null) {
                    setState(() => _secondaryFieldKey = key);
                  }
                },
                onPreparePrint: _selectedRecordIds.isEmpty
                    ? null
                    : () => context.go(
                        '/printing?layout=${_layout.id}',
                        extra: _selectedRecordIds.toList(growable: false),
                      ),
              );
              if (constraints.maxWidth >= 840) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 4, child: selector),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: preview),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  selector,
                  const SizedBox(height: 16),
                  preview,
                ],
              );
            },
          ),
      ],
    );
  }
}

class _LabelLayoutSummary extends StatelessWidget {
  const _LabelLayoutSummary({required this.layout});

  final LabelLayout layout;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppTheme.paleBlue,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.straighten_outlined, color: AppTheme.navy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    layout.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${layout.widthMm.toStringAsFixed(0)} × ${layout.heightMm.toStringAsFixed(0)} mm · Code 128',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5F6B65),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fixed layout with configurable product-field bindings.',
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

class _LabelPreviewPanel extends StatelessWidget {
  const _LabelPreviewPanel({
    required this.record,
    required this.selectedCount,
    required this.primaryFieldKey,
    required this.secondaryFieldKey,
    required this.layout,
    required this.barcodePreview,
    required this.onPrimaryFieldChanged,
    required this.onSecondaryFieldChanged,
    required this.onPreparePrint,
  });

  final CatalogueRecord? record;
  final int selectedCount;
  final String primaryFieldKey;
  final String secondaryFieldKey;
  final LabelLayout layout;
  final BarcodePreview? barcodePreview;
  final ValueChanged<String?> onPrimaryFieldChanged;
  final ValueChanged<String?> onSecondaryFieldChanged;
  final VoidCallback? onPreparePrint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldBindingCard(
          primaryFieldKey: primaryFieldKey,
          secondaryFieldKey: secondaryFieldKey,
          onPrimaryFieldChanged: onPrimaryFieldChanged,
          onSecondaryFieldChanged: onSecondaryFieldChanged,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Preview',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '$selectedCount selected',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF5F6B65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onPreparePrint,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Prepare print'),
                ),
                const SizedBox(height: 16),
                if (record == null)
                  const _SelectRecordPrompt()
                else if (barcodePreview case final BarcodePreview preview?
                    when !preview.isValid)
                  _BarcodeValidationPanel(message: preview.errorMessage!)
                else if (barcodePreview case final BarcodePreview preview?)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AspectRatio(
                        aspectRatio: layout.aspectRatio,
                        child: _LabelPreviewSurface(
                          record: record!,
                          layout: layout,
                          primaryFieldKey: primaryFieldKey,
                          secondaryFieldKey: secondaryFieldKey,
                          barcodePreview: preview,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldBindingCard extends StatelessWidget {
  const _FieldBindingCard({
    required this.primaryFieldKey,
    required this.secondaryFieldKey,
    required this.onPrimaryFieldChanged,
    required this.onSecondaryFieldChanged,
  });

  final String primaryFieldKey;
  final String secondaryFieldKey;
  final ValueChanged<String?> onPrimaryFieldChanged;
  final ValueChanged<String?> onSecondaryFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Field bindings',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text('Choose the imported values shown above the barcode.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: primaryFieldKey,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Primary field'),
              items: _fieldItems(),
              onChanged: onPrimaryFieldChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: secondaryFieldKey,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Secondary field'),
              items: _fieldItems(),
              onChanged: onSecondaryFieldChanged,
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _fieldItems() {
    return productTemplate.fields
        .map(
          (TemplateField field) => DropdownMenuItem<String>(
            value: field.key,
            child: Text(field.displayName),
          ),
        )
        .toList();
  }
}

class _LabelPreviewSurface extends StatelessWidget {
  const _LabelPreviewSurface({
    required this.record,
    required this.layout,
    required this.primaryFieldKey,
    required this.secondaryFieldKey,
    required this.barcodePreview,
  });

  final CatalogueRecord record;
  final LabelLayout layout;
  final String primaryFieldKey;
  final String secondaryFieldKey;
  final BarcodePreview barcodePreview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final pixelsPerMm = constraints.maxWidth / layout.widthMm;
        final horizontalPadding = layout.horizontalPaddingMm * pixelsPerMm;
        final verticalPadding = layout.verticalPaddingMm * pixelsPerMm;
        final barcodeWidth = layout.barcodeWidthMm * pixelsPerMm;
        final barcodeHeight = layout.barcodeHeightMm * pixelsPerMm;
        final barcodeTop =
            constraints.maxHeight -
            verticalPadding -
            barcodeHeight -
            (3 * pixelsPerMm);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: verticalPadding,
                left: horizontalPadding,
                right: horizontalPadding,
                child: Text(
                  record.values[primaryFieldKey]?.trim().isNotEmpty == true
                      ? record.values[primaryFieldKey]!
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 3.8 * pixelsPerMm,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
              ),
              Positioned(
                top: verticalPadding + (5 * pixelsPerMm),
                left: horizontalPadding,
                right: horizontalPadding,
                child: Text(
                  record.values[secondaryFieldKey]?.trim().isNotEmpty == true
                      ? record.values[secondaryFieldKey]!
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 2.6 * pixelsPerMm,
                    color: AppTheme.navy,
                  ),
                ),
              ),
              Positioned(
                top: barcodeTop,
                left: horizontalPadding,
                width: barcodeWidth,
                height: barcodeHeight,
                child: _BarcodeGraphic(preview: barcodePreview),
              ),
              Positioned(
                top: barcodeTop + barcodeHeight,
                left: horizontalPadding,
                width: barcodeWidth,
                height: 3 * pixelsPerMm,
                child: Center(
                  child: Text(
                    record.barcodeValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 2 * pixelsPerMm,
                      letterSpacing: .5,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarcodeGraphic extends StatelessWidget {
  const _BarcodeGraphic({required this.preview});

  final BarcodePreview preview;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BarcodePainter(preview));
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.preview);

  final BarcodePreview preview;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / preview.widthMm;
    final scaleY = size.height / preview.heightMm;
    final paint = Paint()..color = AppTheme.navy;
    for (final mark in preview.marks) {
      canvas.drawRect(
        Rect.fromLTWH(
          mark.leftMm * scaleX,
          mark.topMm * scaleY,
          mark.widthMm * scaleX,
          mark.heightMm * scaleY,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) =>
      oldDelegate.preview != preview;
}

class _LabelsLoadingPanel extends StatelessWidget {
  const _LabelsLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _LabelsLoadError extends StatelessWidget {
  const _LabelsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Records could not be loaded',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Try again. Your locally stored records have not been changed.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoRecordsForLabels extends StatelessWidget {
  const _NoRecordsForLabels({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: AppTheme.navy,
            ),
            const SizedBox(height: 12),
            Text(
              'Import active records to preview labels',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Archived records are intentionally excluded from label preparation.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import CSV'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectRecordPrompt extends StatelessWidget {
  const _SelectRecordPrompt();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Text('Select one or more records to generate a label preview.'),
      ),
    );
  }
}

class _BarcodeValidationPanel extends StatelessWidget {
  const _BarcodeValidationPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('This record cannot be previewed: $message')),
          ],
        ),
      ),
    );
  }
}
