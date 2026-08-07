import 'package:flutter/material.dart';

class ImportsPage extends StatelessWidget {
  const ImportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text('Import data', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'CSV import is the first LabelHub workflow. Select a template, choose a file, then validate every row before saving.',
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Product label',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Required columns: item_code, item_name, barcode'),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.file_open_outlined),
                  label: Text('Choose CSV file'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Import flow UI is ready for the CSV parser and validation use cases.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
