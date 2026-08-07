import 'package:flutter/material.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Records', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          const SearchBar(
            leading: Icon(Icons.search),
            hintText: 'Search by name, SKU, or barcode',
          ),
          const Expanded(
            child: Center(child: Text('Imported records will appear here.')),
          ),
        ],
      ),
    );
  }
}
