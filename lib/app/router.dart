import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/widgets/app_header.dart';
import '../core/presentation/widgets/primary_navigation_bar.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/imports/presentation/imports_page.dart';
import '../features/labels/presentation/labels_page.dart';
import '../features/printing/presentation/printing_page.dart';
import '../features/printing/presentation/printer_settings_page.dart';
import '../features/records/presentation/records_page.dart';
import '../features/records/presentation/record_details_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/templates/presentation/templates_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return _AppShell(location: state.matchedLocation, child: child);
      },
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
        GoRoute(path: '/templates', builder: (_, _) => const TemplatesPage()),
        GoRoute(path: '/imports', builder: (_, _) => const ImportsPage()),
        GoRoute(path: '/records', builder: (_, _) => const RecordsPage()),
        GoRoute(
          path: '/records/:recordId',
          builder: (_, GoRouterState state) =>
              RecordDetailsPage(recordId: state.pathParameters['recordId']!),
        ),
        GoRoute(path: '/labels', builder: (_, _) => const LabelsPage()),
        GoRoute(
          path: '/printing',
          builder: (_, GoRouterState state) {
            final initialRecordIds = switch (state.extra) {
              final List<String> ids => ids,
              _ => const <String>[],
            };
            return PrintingPage(
              initialRecordIds: initialRecordIds,
              initialLayoutId: state.uri.queryParameters['layout'],
              initialPrimaryFieldKey:
                  state.uri.queryParameters['primaryField'] ?? 'item_name',
              initialSecondaryFieldKey:
                  state.uri.queryParameters['secondaryField'] ?? 'price',
            );
          },
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/settings/printers',
          builder: (_, _) => const PrinterSettingsPage(),
        ),
        GoRoute(
          path: '/printer-settings',
          redirect: (_, _) => '/settings/printers',
        ),
      ],
    ),
  ],
);

class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});

  final String location;
  final Widget child;

  static const _destinations = <PrimaryNavigationDestination>[
    PrimaryNavigationDestination(
      icon: Icons.view_list_outlined,
      label: 'Templates',
    ),
    PrimaryNavigationDestination(
      icon: Icons.inventory_2_outlined,
      label: 'Records',
    ),
    PrimaryNavigationDestination(icon: Icons.home_rounded, label: 'Dashboard'),
    PrimaryNavigationDestination(
      icon: Icons.file_upload_outlined,
      label: 'Import',
    ),
    PrimaryNavigationDestination(
      icon: Icons.local_offer_outlined,
      label: 'Labels',
    ),
  ];

  static const _locations = <String>[
    '/templates',
    '/records',
    '/',
    '/imports',
    '/labels',
  ];

  @override
  Widget build(BuildContext context) {
    final index = _locations.indexOf(location).clamp(0, _locations.length - 1);
    return Scaffold(
      body: Column(
        children: <Widget>[
          AppHeader(onSettingsPressed: () => context.go('/settings')),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: PrimaryNavigationBar(
        destinations: _destinations,
        selectedIndex: index,
        onSelected: (int selected) => context.go(_locations[selected]),
      ),
    );
  }
}
