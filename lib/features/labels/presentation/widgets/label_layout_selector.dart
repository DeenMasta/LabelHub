import 'package:flutter/material.dart';

import '../../domain/entities/label_layout.dart';

/// Selects one of the supported fixed product-label dimensions.
class LabelLayoutSelector extends StatelessWidget {
  const LabelLayoutSelector({
    required this.selectedLayout,
    required this.onChanged,
    super.key,
  });

  final LabelLayout selectedLayout;
  final ValueChanged<LabelLayout?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<LabelLayout>(
      initialValue: selectedLayout,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Label size'),
      items: productLabelLayouts
          .map(
            (LabelLayout layout) => DropdownMenuItem<LabelLayout>(
              value: layout,
              child: Text(
                '${layout.name} · ${layout.widthMm.toStringAsFixed(0)} × ${layout.heightMm.toStringAsFixed(0)} mm',
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
