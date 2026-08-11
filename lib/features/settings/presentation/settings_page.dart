import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';

/// Provides a single home for application and hardware configuration.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageContent(
      children: <Widget>[
        const PageHeading(
          eyebrow: 'Application',
          title: 'Settings',
          description:
              'Manage the equipment and preferences LabelHub uses for daily work.',
        ),
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            minVerticalPadding: 16,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: const Icon(Icons.print_outlined),
            title: const Text(
              'Printers',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Set up Bluetooth and network printer profiles for label printing.',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go('/settings/printers'),
          ),
        ),
      ],
    );
  }
}
