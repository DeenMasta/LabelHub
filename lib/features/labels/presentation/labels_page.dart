import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../../templates/data/builtin_templates.dart';
import '../../templates/domain/entities/import_template.dart';
import '../data/barcode_preview_service.dart';
import '../domain/entities/barcode_request.dart';
import '../domain/entities/label_layout.dart';
import 'widgets/label_layout_selector.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({super.key});

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  static const _barcodeService = BarcodePreviewService();
  static const _sampleBarcodeValue = 'DEMO-123456';

  String _primaryFieldKey = 'item_name';
  String _secondaryFieldKey = 'price';
  LabelLayout _layout = productLabelLayout;

  BarcodePreview get _sampleBarcodePreview => _barcodeService.create(
    BarcodeRequest(
      value: _sampleBarcodeValue,
      format: productTemplate.barcodeFormat,
      widthMm: _layout.barcodeWidthMm,
      heightMm: _layout.barcodeHeightMm,
      showText: false,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AppPageContent(
      children: <Widget>[
        const PageHeading(
          eyebrow: 'Output',
          title: 'Label preview',
          description:
              'Choose what the label prints, then review the general layout before selecting products.',
        ),
        const SizedBox(height: 20),
        _LabelLayoutSummary(layout: _layout),
        const SizedBox(height: 12),
        LabelLayoutSelector(
          selectedLayout: _layout,
          onChanged: (LabelLayout? layout) {
            if (layout != null) {
              setState(() => _layout = layout);
            }
          },
        ),
        const SizedBox(height: 16),
        _LabelPreviewPanel(
          primaryFieldKey: _primaryFieldKey,
          secondaryFieldKey: _secondaryFieldKey,
          layout: _layout,
          barcodePreview: _sampleBarcodePreview,
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
          onPreparePrint: () => context.go(
            Uri(
              path: '/printing',
              queryParameters: <String, String>{
                'layout': _layout.id,
                'primaryField': _primaryFieldKey,
                'secondaryField': _secondaryFieldKey,
              },
            ).toString(),
          ),
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
    required this.primaryFieldKey,
    required this.secondaryFieldKey,
    required this.layout,
    required this.barcodePreview,
    required this.onPrimaryFieldChanged,
    required this.onSecondaryFieldChanged,
    required this.onPreparePrint,
  });

  final String primaryFieldKey;
  final String secondaryFieldKey;
  final LabelLayout layout;
  final BarcodePreview barcodePreview;
  final ValueChanged<String?> onPrimaryFieldChanged;
  final ValueChanged<String?> onSecondaryFieldChanged;
  final VoidCallback onPreparePrint;

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
                        '2. General preview',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Chip(label: Text('Sample')),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AspectRatio(
                      aspectRatio: layout.aspectRatio,
                      child: _LabelPreviewSurface(
                        layout: layout,
                        primaryText: _fieldDisplayName(primaryFieldKey),
                        secondaryText: _fieldDisplayName(secondaryFieldKey),
                        barcodeValue: 'DEMO-123456',
                        barcodePreview: barcodePreview,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onPreparePrint,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Choose products to print'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fieldDisplayName(String fieldKey) {
    if (fieldKey.isEmpty) {
      return '';
    }
    for (final field in productTemplate.fields) {
      if (field.key == fieldKey) {
        return field.displayName;
      }
    }
    return '';
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
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
                    child: Icon(
                      Icons.text_fields_rounded,
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
                        '1. Label content',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose the product fields printed above the barcode.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final primaryField = DropdownButtonFormField<String>(
                  initialValue: primaryFieldKey,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Top line'),
                  items: _fieldItems(),
                  onChanged: onPrimaryFieldChanged,
                );
                final secondaryField = DropdownButtonFormField<String>(
                  initialValue: secondaryFieldKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Second line (optional)',
                  ),
                  items: _fieldItems(includeNoSecondLine: true),
                  onChanged: onSecondaryFieldChanged,
                );
                if (constraints.maxWidth >= 520) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: primaryField),
                      const SizedBox(width: 12),
                      Expanded(child: secondaryField),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    primaryField,
                    const SizedBox(height: 12),
                    secondaryField,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Choose “No second line” for a one-line label.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _fieldItems({
    bool includeNoSecondLine = false,
  }) {
    return <DropdownMenuItem<String>>[
      if (includeNoSecondLine)
        const DropdownMenuItem<String>(
          value: '',
          child: Text('No second line'),
        ),
      for (final TemplateField field in productTemplate.fields)
        DropdownMenuItem<String>(
          value: field.key,
          child: Text(field.displayName),
        ),
    ];
  }
}

class _LabelPreviewSurface extends StatelessWidget {
  const _LabelPreviewSurface({
    required this.layout,
    required this.primaryText,
    required this.secondaryText,
    required this.barcodeValue,
    required this.barcodePreview,
  });

  final LabelLayout layout;
  final String primaryText;
  final String secondaryText;
  final String barcodeValue;
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
                  primaryText,
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
                  secondaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 3 * pixelsPerMm,
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
                    barcodeValue,
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
