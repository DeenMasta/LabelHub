import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../data/record_repository.dart';
import '../domain/entities/catalogue_record.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  List<CatalogueRecord> _records = const <CatalogueRecord>[];
  String _query = '';
  _RecordVisibility _visibility = _RecordVisibility.active;
  Object? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final database = await ref.read(appDatabaseProvider.future);
      final records = await RecordRepository(database).list();
      if (!mounted) {
        return;
      }
      setState(() => _records = records);
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

  List<CatalogueRecord> get _visibleRecords {
    final query = _query.trim().toLowerCase();
    return _records.where((CatalogueRecord record) {
      final matchesVisibility = switch (_visibility) {
        _RecordVisibility.active => !record.isArchived,
        _RecordVisibility.archived => record.isArchived,
        _RecordVisibility.all => true,
      };
      if (!matchesVisibility || query.isEmpty) {
        return matchesVisibility;
      }
      return <String>[
        record.reference,
        record.barcodeValue,
        ...record.values.values,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final records = _visibleRecords;
    return AppPageContent(
      children: <Widget>[
        const PageHeading(
          eyebrow: 'Catalogue',
          title: 'Records',
          description:
              'Search, review, and maintain imported product information before printing labels.',
        ),
        const SizedBox(height: 20),
        SearchBar(
          leading: const Icon(Icons.search_rounded),
          hintText: 'Search name, item code, or barcode',
          onChanged: (String query) => setState(() => _query = query),
        ),
        const SizedBox(height: 12),
        _RecordFilters(
          selected: _visibility,
          onSelected: (_RecordVisibility visibility) {
            setState(() => _visibility = visibility);
          },
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_loadError != null)
          _RecordsLoadError(onRetry: _loadRecords)
        else if (_records.isEmpty)
          _EmptyRecordsPanel(onImport: () => context.go('/imports'))
        else if (records.isEmpty)
          _NoMatchingRecords(
            query: _query,
            onClear: () => setState(() => _query = ''),
          )
        else ...<Widget>[
          Text(
            '${records.length} ${records.length == 1 ? 'record' : 'records'}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF5F6B65),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final record in records) ...<Widget>[
            _RecordListCard(
              record: record,
              onOpen: () => context.go('/records/${record.id}'),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

enum _RecordVisibility { active, archived, all }

class _RecordFilters extends StatelessWidget {
  const _RecordFilters({required this.selected, required this.onSelected});

  final _RecordVisibility selected;
  final ValueChanged<_RecordVisibility> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final visibility in _RecordVisibility.values)
          FilterChip(
            label: Text(switch (visibility) {
              _RecordVisibility.active => 'Active',
              _RecordVisibility.archived => 'Archived',
              _RecordVisibility.all => 'All records',
            }),
            selected: selected == visibility,
            onSelected: (_) => onSelected(visibility),
          ),
      ],
    );
  }
}

class _RecordListCard extends StatelessWidget {
  const _RecordListCard({required this.record, required this.onOpen});

  final CatalogueRecord record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final details = <Widget>[
                Text(
                  record.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.reference}  ·  ${record.barcodeValue}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5F6B65),
                  ),
                ),
              ];
              final status = _RecordStatusBadge(isArchived: record.isArchived);
              return constraints.maxWidth < 420
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ...details,
                        const SizedBox(height: 12),
                        status,
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: details,
                          ),
                        ),
                        const SizedBox(width: 16),
                        status,
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}

class _RecordStatusBadge extends StatelessWidget {
  const _RecordStatusBadge({required this.isArchived});

  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isArchived ? const Color(0xFFECEFED) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          isArchived ? 'Archived' : 'Active',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF121C2A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RecordsLoadError extends StatelessWidget {
  const _RecordsLoadError({required this.onRetry});

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
              'Records could not be loaded',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Try again. Your locally stored records have not been changed.',
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

class _NoMatchingRecords extends StatelessWidget {
  const _NoMatchingRecords({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const Icon(Icons.search_off_rounded, size: 36),
            const SizedBox(height: 12),
            Text(
              'No matching records',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              query.trim().isEmpty
                  ? 'Try another filter.'
                  : 'Try a different search term.',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecordsPanel extends StatelessWidget {
  const _EmptyRecordsPanel({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFBFDBFE),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF121C2A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your catalogue is ready for its first import',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Import a completed product CSV to create searchable records and prepare them for printing.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5F6B65),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import CSV'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
