import 'package:flutter/material.dart';

import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';

class LabelsPage extends StatelessWidget {
  const LabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageContent(
      children: <Widget>[
        const PageHeading(
          eyebrow: 'Output',
          title: 'Labels & printing',
          description:
              'Your saved records will appear here as soon as label layouts and printing are configured.',
        ),
        const SizedBox(height: 24),
        const _PrintingStatusPanel(),
        const SizedBox(height: 16),
        const _PrintCapabilityList(),
      ],
    );
  }
}

class _PrintingStatusPanel extends StatelessWidget {
  const _PrintingStatusPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF292D2D),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF3C4241),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.print_outlined, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Print-ready layouts are next',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'LabelHub keeps the physical dimensions in millimetres, then renders barcodes and layouts at the print boundary.',
              style: TextStyle(color: Color(0xFFC5CECA), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintCapabilityList extends StatelessWidget {
  const _PrintCapabilityList();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: const <Widget>[
          _PrintCapabilityRow(
            icon: Icons.straighten_outlined,
            title: 'Accurate physical sizing',
            detail:
                'Millimetres are converted to PDF points and printer dots only when needed.',
          ),
          Divider(height: 1),
          _PrintCapabilityRow(
            icon: Icons.qr_code_2_outlined,
            title: 'Barcode-ready records',
            detail:
                'Code 128, Code 39, EAN-13, and QR code formats are supported.',
          ),
        ],
      ),
    );
  }
}

class _PrintCapabilityRow extends StatelessWidget {
  const _PrintCapabilityRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
