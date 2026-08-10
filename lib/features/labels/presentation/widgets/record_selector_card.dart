import 'package:flutter/material.dart';

import '../../../records/domain/entities/catalogue_record.dart';

/// Lets label preparation features select active catalogue records.
class RecordSelectorCard extends StatelessWidget {
  const RecordSelectorCard({
    required this.records,
    required this.selectedRecordIds,
    required this.onChanged,
    this.title = 'Records to preview',
    this.description = 'The first selected record is shown in the preview.',
    super.key,
  });

  final List<CatalogueRecord> records;
  final Set<String> selectedRecordIds;
  final void Function(CatalogueRecord record, bool selected) onChanged;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(description),
            ),
            const SizedBox(height: 8),
            for (final record in records)
              CheckboxListTile(
                value: selectedRecordIds.contains(record.id),
                onChanged: (bool? selected) =>
                    onChanged(record, selected ?? false),
                title: Text(
                  record.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${record.reference} · ${record.barcodeValue}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
        ),
      ),
    );
  }
}
