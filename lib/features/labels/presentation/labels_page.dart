import 'package:flutter/material.dart';

class LabelsPage extends StatelessWidget {
  const LabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'Labels & printing',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Fixed layouts use millimetres internally and will render to PDF before the system print dialog opens.',
        ),
        const SizedBox(height: 24),
        const Card(
          child: ListTile(
            leading: Icon(Icons.straighten),
            title: Text('Physical sizing'),
            subtitle: Text(
              '1 mm = 72 / 25.4 PDF points; printer dots are calculated from DPI.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: ListTile(
            leading: Icon(Icons.qr_code_2),
            title: Text('Barcode formats'),
            subtitle: Text(
              'Code 128, Code 39, EAN-13 and QR code are supported by the app foundation.',
            ),
          ),
        ),
      ],
    );
  }
}
