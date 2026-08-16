import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../printing/data/printer_profile_repository.dart';
import '../../printing/domain/entities/printer_profile.dart';
import '../../records/data/record_repository.dart';
import '../../records/domain/entities/catalogue_record.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  _DashboardSnapshot? _snapshot;
  Object? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Future<void> _loadDashboard() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final database = await ref.read(appDatabaseProvider.future);
      final printerProfiles = PrinterProfileRepository(database);
      final results = await Future.wait<Object?>(<Future<Object?>>[
        RecordRepository(database).list(),
        printerProfiles.list(),
        printerProfiles.defaultProfileId(),
      ]);
      final records = results[0]! as List<CatalogueRecord>
        ..sort(
          (CatalogueRecord first, CatalogueRecord second) =>
              second.updatedAt.compareTo(first.updatedAt),
        );
      final profiles = results[1]! as List<PrinterProfile>;
      final defaultProfileId = results[2] as String?;
      PrinterProfile? defaultPrinter;
      for (final profile in profiles) {
        if (profile.id == defaultProfileId) {
          defaultPrinter = profile;
          break;
        }
      }
      if (!mounted) {
        return;
      }
      setState(
        () => _snapshot = _DashboardSnapshot(
          records: records,
          defaultPrinter: defaultPrinter,
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageContent(
      children: <Widget>[
        if (_isLoading)
          const _DashboardLoadingPanel()
        else if (_loadError != null)
          _DashboardLoadError(onRetry: _loadDashboard)
        else if (_snapshot case final snapshot?) ...<Widget>[
          _DashboardHero(snapshot: snapshot),
          const SizedBox(height: 20),
          _DashboardMetrics(snapshot: snapshot),
          if (snapshot.records.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            _RecentRecordsCard(records: snapshot.recentRecords),
          ],
        ],
      ],
    );
  }
}

class _DashboardSnapshot {
  const _DashboardSnapshot({
    required this.records,
    required this.defaultPrinter,
  });

  final List<CatalogueRecord> records;
  final PrinterProfile? defaultPrinter;

  List<CatalogueRecord> get recentRecords => records.take(3).toList();
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.snapshot});

  final _DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final nextStep = _nextStep;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'WORKSPACE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.paleBlue,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Label operations',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              nextStep.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFD3DAE2),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go(nextStep.path),
              icon: Icon(nextStep.icon),
              label: Text(nextStep.actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _DashboardNextStep get _nextStep {
    if (snapshot.records.isEmpty) {
      return const _DashboardNextStep(
        description:
            'Import your product catalogue to make verified records available for label printing.',
        actionLabel: 'Import products',
        icon: Icons.file_upload_outlined,
        path: '/imports',
      );
    }
    if (snapshot.defaultPrinter == null) {
      return const _DashboardNextStep(
        description:
            'Your catalogue is ready. Set a default printer to begin sending labels directly from LabelHub.',
        actionLabel: 'Set up printer',
        icon: Icons.settings_outlined,
        path: '/settings/printers',
      );
    }
    return _DashboardNextStep(
      description:
          '${snapshot.records.length} ${_productNoun(snapshot.records.length)} are ready to print with ${snapshot.defaultPrinter!.name}.',
      actionLabel: 'Prepare labels',
      icon: Icons.print_outlined,
      path: '/labels',
    );
  }
}

class _DashboardNextStep {
  const _DashboardNextStep({
    required this.description,
    required this.actionLabel,
    required this.icon,
    required this.path,
  });

  final String description;
  final String actionLabel;
  final IconData icon;
  final String path;
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics({required this.snapshot});

  final _DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _DashboardMetricCard(
        label: 'Catalogue',
        value: '${snapshot.records.length}',
        detail:
            '${snapshot.records.length} ${_productNoun(snapshot.records.length)} ready to label',
      ),
      _DashboardMetricCard(
        label: 'Default printer',
        value: snapshot.defaultPrinter?.name ?? 'Not configured',
        detail: snapshot.defaultPrinter == null
            ? 'Set a printer before your first print run'
            : 'Ready for direct label printing',
        isCompactValue: snapshot.defaultPrinter != null,
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[cards[0], const SizedBox(height: 12), cards[1]],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.detail,
    this.isCompactValue = false,
  });

  final String label;
  final String value;
  final String detail;
  final bool isCompactValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.accentBlue,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (isCompactValue
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineSmall)
                      ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRecordsCard extends StatelessWidget {
  const _RecentRecordsCard({required this.records});

  final List<CatalogueRecord> records;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Recently updated',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Latest changes in your product catalogue.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/records'),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < records.length; index++) ...<Widget>[
              _RecentRecordRow(record: records[index]),
              if (index < records.length - 1)
                const Divider(height: 1, color: AppTheme.border),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentRecordRow extends StatelessWidget {
  const _RecentRecordRow({required this.record});

  final CatalogueRecord record;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${record.name}',
      child: InkWell(
        onTap: () => context.go('/records/${record.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'SKU ${record.reference} / ${_updatedLabel(record.updatedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardLoadingPanel extends StatelessWidget {
  const _DashboardLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DashboardLoadError extends StatelessWidget {
  const _DashboardLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Dashboard could not be loaded',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your locally stored records have not been changed.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedInk),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _productNoun(int count) => count == 1 ? 'product' : 'products';

String _updatedLabel(DateTime updatedAt) {
  final now = DateTime.now().toUtc();
  final date = updatedAt.toUtc();
  final difference = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(date.year, date.month, date.day));
  if (difference.inDays <= 0) {
    return 'updated today';
  }
  if (difference.inDays == 1) {
    return 'updated yesterday';
  }
  if (difference.inDays < 7) {
    return 'updated ${difference.inDays} days ago';
  }
  const monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final year = date.year == now.year ? '' : ' ${date.year}';
  return 'updated ${monthNames[date.month - 1]} ${date.day}$year';
}
