import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/widgets/app_header.dart';
import '../core/presentation/widgets/primary_navigation_bar.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/imports/presentation/imports_page.dart';
import '../features/labels/presentation/labels_page.dart';
import '../features/records/presentation/records_page.dart';
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
        GoRoute(path: '/labels', builder: (_, _) => const LabelsPage()),
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
          const AppHeader(),
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
