import 'package:flutter/material.dart';

import '../data/builtin_templates.dart';

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text('Templates', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Templates define the columns and validation rules for your imports.',
        ),
        const SizedBox(height: 20),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(productTemplate.name),
            subtitle: Text(productTemplate.description),
            children: <Widget>[
              for (final field in productTemplate.fields)
                ListTile(
                  dense: true,
                  title: Text(field.displayName),
                  subtitle: Text(
                    '${field.dataType.name}${field.required ? ' · Required' : ' · Optional'}${field.example == null ? '' : ' · ${field.example}'}',
                  ),
                  trailing: field.required
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
