import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../../../core/printing/printer_catalog.dart';
import '../../../core/printing/tspl_label_command_encoder.dart';
import '../../labels/domain/entities/label_layout.dart';
import '../../printing/data/direct_label_print_service.dart';
import '../../printing/data/printer_profile_repository.dart';
import '../data/record_repository.dart';
import '../domain/entities/catalogue_record.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  final _searchController = SearchController();
  List<CatalogueRecord> _records = const <CatalogueRecord>[];
  String _query = '';
  String? _categoryKey;
  _RecordSort _sort = _RecordSort.sku;
  Object? _loadError;
  bool _isLoading = true;
  bool _isPrinting = false;
  final Set<String> _selectedRecordIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final records = _records.where((CatalogueRecord record) {
      final matchesCategory =
          _categoryKey == null || record.categoryKey == _categoryKey;
      if (!matchesCategory || query.isEmpty) {
        return matchesCategory;
      }
      return <String>[
        record.reference,
        record.barcodeValue,
        ...record.values.values,
      ].join(' ').toLowerCase().contains(query);
    }).toList()..sort(_compareRecords);
    return records;
  }

  List<_RecordCategory> get _categories {
    final categories = <String, _RecordCategory>{};
    for (final record in _records) {
      final category = record.category;
      final key = record.categoryKey;
      if (category != null && key != null) {
        categories.putIfAbsent(key, () => _RecordCategory(key, category));
      }
    }
    return categories.values.toList()..sort(
      (_RecordCategory first, _RecordCategory second) =>
          first.label.toLowerCase().compareTo(second.label.toLowerCase()),
    );
  }

  int _compareRecords(CatalogueRecord first, CatalogueRecord second) {
    final comparison = switch (_sort) {
      _RecordSort.sku => _compareText(first.reference, second.reference),
      _RecordSort.name => _compareText(first.name, second.name),
      _RecordSort.category => _compareText(
        first.category ?? '\uffff',
        second.category ?? '\uffff',
      ),
      _RecordSort.lastUpdated => second.updatedAt.compareTo(first.updatedAt),
    };
    return comparison != 0 ? comparison : first.id.compareTo(second.id);
  }

  int _compareText(String first, String second) =>
      first.toLowerCase().compareTo(second.toLowerCase());

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _categoryKey = null;
      _sort = _RecordSort.sku;
      _selectedRecordIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedRecordIds.contains(id)) {
        _selectedRecordIds.remove(id);
      } else {
        _selectedRecordIds.add(id);
      }
    });
  }

  void _selectAll(List<CatalogueRecord> records) {
    setState(() {
      _selectedRecordIds.addAll(records.map((r) => r.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedRecordIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final idsToDelete = _selectedRecordIds.toList();
    if (idsToDelete.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected products?'),
        content: Text('Are you sure you want to delete ${idsToDelete.length} products? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final database = await ref.read(appDatabaseProvider.future);
      final recordsToDelete = _records.where((r) => idsToDelete.contains(r.id)).toList();
      await RecordRepository(database).deleteMany(recordsToDelete);
      
      _selectedRecordIds.clear();
      await _loadRecords();
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete products: $error')),
        );
      }
    }
  }

  Future<void> _printSelected() async {
    final idsToPrint = _selectedRecordIds.toList();
    if (idsToPrint.isEmpty) return;

    final recordsToPrint = _records.where((r) => idsToPrint.contains(r.id)).toList();

    final recordCopies = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => _BulkPrintQuantityDialog(records: recordsToPrint),
    );

    if (recordCopies == null || recordCopies.isEmpty || !mounted) return;

    setState(() => _isPrinting = true);
    
    try {
      final database = await ref.read(appDatabaseProvider.future);
      await DirectLabelPrintService(
        printerProfiles: PrinterProfileRepository(database),
        printerCatalog: PrinterCatalog(),
      ).print(
        records: recordsToPrint,
        recordCopies: recordCopies,
        layout: productLabelLayout,
        primaryFieldKey: 'item_name',
        secondaryFieldKey: 'price',
      );
      
      final totalLabels = recordCopies.values.fold(0, (sum, val) => sum + val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent $totalLabels ${totalLabels == 1 ? 'label' : 'labels'} to the default printer.')),
        );
      }
      
      setState(() {
        _selectedRecordIds.clear();
      });
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_printErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  String _printErrorMessage(Object error) {
    final technicalMessage = error.toString().toLowerCase();
    if (technicalMessage.contains('bluetooth_scan') ||
        technicalMessage.contains('bluetooth_connect') ||
        technicalMessage.contains('nearby devices permission')) {
      return 'Allow Nearby devices permission to use paired Bluetooth printers, then try again.';
    }
    return switch (error) {
      DirectLabelPrintException exception => exception.message,
      TsplPrintingException exception => exception.message,
      PlatformException exception =>
        exception.message ?? 'The default printer could not be reached.',
      _ => 'The labels could not be prepared for printing. Try again.',
    };
  }


  @override
  Widget build(BuildContext context) {
    final records = _visibleRecords;
    return Stack(
      children: <Widget>[
        AppPageContent(
          children: <Widget>[
            const PageHeading(
              eyebrow: 'Product catalogue',
              title: 'Records',
              description:
                  'Find product data quickly, keep your catalogue current, and prepare records for label printing.',
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const _RecordsLoadingPanel()
            else if (_loadError != null)
              _RecordsLoadError(onRetry: _loadRecords)
            else if (_records.isEmpty)
              const _EmptyRecordsPanel()
            else ...<Widget>[
              _RecordSearchCard(
                controller: _searchController,
                selectedCategoryKey: _categoryKey,
                categories: _categories,
                selectedSort: _sort,
                onQueryChanged: (String query) =>
                    setState(() => _query = query),
                onCategorySelected: (String? categoryKey) {
                  setState(() => _categoryKey = categoryKey);
                },
                onSortSelected: (_RecordSort sort) {
                  setState(() => _sort = sort);
                },
              ),
              const SizedBox(height: 20),
              if (records.isEmpty)
                _NoMatchingRecords(query: _query, onReset: _resetFilters)
              else ...<Widget>[
                Row(
                  children: [
                    Expanded(
                      child: _RecordResultsHeader(
                        shownRecords: records.length,
                        totalRecords: _records.length,
                      ),
                    ),
                    if (_selectedRecordIds.isNotEmpty)
                      TextButton(
                        onPressed: _clearSelection,
                        child: const Text('Clear'),
                      ),
                    TextButton(
                      onPressed: () => _selectAll(records),
                      child: const Text('Select all'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (
                  var index = 0;
                  index < records.length;
                  index++
                ) ...<Widget>[
                  _RecordListCard(
                    record: records[index],
                    isSelected: _selectedRecordIds.contains(records[index].id),
                    onToggle: (bool? _) => _toggleSelection(records[index].id),
                    onOpen: () => context.go('/records/${records[index].id}'),
                  ),
                  if (index < records.length - 1) const SizedBox(height: 12),
                ],
              ],
            ],
            const SizedBox(height: 72),
          ],
        ),
        if (!_isLoading && _loadError == null)
          Positioned(
            right: 20,
            bottom: 20,
            child: _selectedRecordIds.isNotEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.extended(
                        key: const Key('records-delete-button'),
                        heroTag: 'records-delete',
                        onPressed: _isPrinting ? null : _deleteSelected,
                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                        icon: const Icon(Icons.delete_outline),
                        label: Text('Delete ${_selectedRecordIds.length}'),
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton.extended(
                        key: const Key('records-print-button'),
                        heroTag: 'records-print',
                        onPressed: _isPrinting ? null : _printSelected,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(LucideIcons.printer),
                        label: Text('Print ${_selectedRecordIds.length}'),
                      ),
                    ],
                  )
                : FloatingActionButton.extended(
                    key: const Key('records-import-button'),
                    heroTag: 'records-import',
                    onPressed: () => context.go('/imports'),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import products'),
                  ),
          ),
      ],
    );
  }
}

enum _RecordSort { sku, name, category, lastUpdated }

class _RecordCategory {
  const _RecordCategory(this.key, this.label);

  final String key;
  final String label;
}

class _RecordsLoadingPanel extends StatelessWidget {
  const _RecordsLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _RecordSearchCard extends StatelessWidget {
  const _RecordSearchCard({
    required this.controller,
    required this.selectedCategoryKey,
    required this.categories,
    required this.selectedSort,
    required this.onQueryChanged,
    required this.onCategorySelected,
    required this.onSortSelected,
  });

  final SearchController controller;
  final String? selectedCategoryKey;
  final List<_RecordCategory> categories;
  final _RecordSort selectedSort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<_RecordSort> onSortSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Find, filter, and sort',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SearchBar(
              controller: controller,
              leading: const Icon(Icons.search_rounded),
              hintText: 'Search product, SKU, or barcode',
              onChanged: onQueryChanged,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final categoryFilter = _CategoryFilter(
                  selectedCategoryKey: selectedCategoryKey,
                  categories: categories,
                  onSelected: onCategorySelected,
                );
                final sortSelector = _RecordSortSelector(
                  selected: selectedSort,
                  onSelected: onSortSelected,
                );
                if (constraints.maxWidth >= 520) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: categoryFilter),
                      const SizedBox(width: 12),
                      Expanded(child: sortSelector),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    categoryFilter,
                    const SizedBox(height: 12),
                    sortSelector,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selectedCategoryKey,
    required this.categories,
    required this.onSelected,
  });

  final String? selectedCategoryKey;
  final List<_RecordCategory> categories;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('record-category-filter'),
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>(selectedCategoryKey ?? ''),
        initialValue: selectedCategoryKey ?? '',
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Category',
          prefixIcon: Icon(Icons.category_outlined),
        ),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(
            value: '',
            child: Text('All categories'),
          ),
          for (final category in categories)
            DropdownMenuItem<String>(
              value: category.key,
              child: Text(category.label),
            ),
        ],
        onChanged: (String? categoryKey) => onSelected(
          categoryKey == null || categoryKey.isEmpty ? null : categoryKey,
        ),
      ),
    );
  }
}

class _RecordSortSelector extends StatelessWidget {
  const _RecordSortSelector({required this.selected, required this.onSelected});

  final _RecordSort selected;
  final ValueChanged<_RecordSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('record-sort-selector'),
      child: DropdownButtonFormField<_RecordSort>(
        key: ValueKey<_RecordSort>(selected),
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Sort by',
          prefixIcon: Icon(Icons.sort_rounded),
        ),
        items: <DropdownMenuItem<_RecordSort>>[
          for (final sort in _RecordSort.values)
            DropdownMenuItem<_RecordSort>(
              value: sort,
              child: Text(switch (sort) {
                _RecordSort.sku => 'SKU / ID',
                _RecordSort.name => 'Name (A-Z)',
                _RecordSort.category => 'Category (A-Z)',
                _RecordSort.lastUpdated => 'Last updated',
              }),
            ),
        ],
        onChanged: (_RecordSort? sort) {
          if (sort != null) {
            onSelected(sort);
          }
        },
      ),
    );
  }
}

class _RecordResultsHeader extends StatelessWidget {
  const _RecordResultsHeader({
    required this.shownRecords,
    required this.totalRecords,
  });

  final int shownRecords;
  final int totalRecords;

  @override
  Widget build(BuildContext context) {
    final label = shownRecords == 1 ? 'product' : 'products';
    final detail = shownRecords == totalRecords
        ? '$shownRecords $label'
        : '$shownRecords of $totalRecords $label';
    return Text(
      detail,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _RecordListCard extends StatelessWidget {
  const _RecordListCard({
    required this.record,
    required this.isSelected,
    required this.onToggle,
    required this.onOpen,
  });

  final CatalogueRecord record;
  final bool isSelected;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final details = _RecordDetails(record: record);
    return Semantics(
      button: true,
      label: 'Open ${record.name}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth < 440) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Checkbox(
                            value: isSelected,
                            onChanged: onToggle,
                          ),
                          const _RecordIcon(),
                          const SizedBox(width: 12),
                          Expanded(child: details),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          const Spacer(),
                          Text(
                            'View details',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Checkbox(
                      value: isSelected,
                      onChanged: onToggle,
                    ),
                    const _RecordIcon(),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordIcon extends StatelessWidget {
  const _RecordIcon();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.paleBlueSurface,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(Icons.inventory_2_outlined, color: AppTheme.navy),
      ),
    );
  }
}

class _RecordDetails extends StatelessWidget {
  const _RecordDetails({required this.record});

  final CatalogueRecord record;

  @override
  Widget build(BuildContext context) {
    final metadata = <Widget>[
      if (_fieldValue('category') case final category?)
        _RecordMetadata(label: 'Category', value: category),
      if (_fieldValue('price') case final price?)
        _RecordMetadata(label: 'Price', value: price),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          record.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'SKU ${record.reference} · Barcode ${record.barcodeValue}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5F6B65)),
        ),
        if (metadata.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: metadata),
        ],
      ],
    );
  }

  String? _fieldValue(String key) {
    if (key == 'category') {
      return record.category;
    }
    final value = record.values[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

class _RecordMetadata extends StatelessWidget {
  const _RecordMetadata({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.navy,
            fontWeight: FontWeight.w700,
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
  const _NoMatchingRecords({required this.query, required this.onReset});

  final String query;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.paleBlueSurface,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.search_off_rounded, color: AppTheme.navy),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching products',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Try a different product name, SKU, or barcode.'
                  : 'Choose another category or reset the filters.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5F6B65)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Show all records'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecordsPanel extends StatelessWidget {
  const _EmptyRecordsPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.paleBlue,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.inventory_2_outlined, color: AppTheme.navy),
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
              'Import a CSV or XLSX product file to create searchable records and prepare them for printing.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5F6B65),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/imports'),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import products'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkPrintQuantityDialog extends StatefulWidget {
  const _BulkPrintQuantityDialog({required this.records});

  final List<CatalogueRecord> records;

  @override
  State<_BulkPrintQuantityDialog> createState() => _BulkPrintQuantityDialogState();
}

class _BulkPrintQuantityDialogState extends State<_BulkPrintQuantityDialog> {
  final Map<String, int> _copies = {};
  final Map<String, TextEditingController> _controllers = {};
  String? _generalError;

  @override
  void initState() {
    super.initState();
    for (final record in widget.records) {
      _copies[record.id] = 1;
      _controllers[record.id] = TextEditingController(text: '1');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setCopies(String id, int copies) {
    setState(() {
      _copies[id] = copies;
      _controllers[id]?.text = '$copies';
      _generalError = null;
    });
  }

  void _continueToPrint() {
    final copiesResult = <String, int>{};
    for (final record in widget.records) {
      final copies = int.tryParse(_controllers[record.id]?.text ?? '0');
      if (copies == null || copies < 0) {
        setState(() => _generalError = 'Please enter valid numbers.');
        return;
      }
      if (copies > 0) {
        copiesResult[record.id] = copies;
      }
    }
    
    if (copiesResult.isEmpty) {
      setState(() => _generalError = 'Enter at least 1 label for one product.');
      return;
    }
    
    Navigator.pop(context, copiesResult);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Print ${widget.records.length} products',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set label quantity for each product.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedInk),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppTheme.border),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                itemCount: widget.records.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final record = widget.records[index];
                  final currentCopies = _copies[record.id] ?? 1;
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          IconButton.outlined(
                            tooltip: 'Decrease quantity',
                            style: IconButton.styleFrom(
                              minimumSize: const Size.square(40),
                              maximumSize: const Size.square(40),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                              ),
                            ),
                            onPressed: currentCopies > 0
                                ? () => _setCopies(record.id, currentCopies - 1)
                                : null,
                            icon: const Icon(LucideIcons.minus, size: 16),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              controller: _controllers[record.id],
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (String value) {
                                final copies = int.tryParse(value);
                                if (copies != null && copies >= 0) {
                                  setState(() {
                                    _copies[record.id] = copies;
                                    _generalError = null;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Increase quantity',
                            style: IconButton.styleFrom(
                              minimumSize: const Size.square(40),
                              maximumSize: const Size.square(40),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                              ),
                            ),
                            onPressed: () => _setCopies(record.id, currentCopies + 1),
                            icon: const Icon(LucideIcons.plus, size: 16),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_generalError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _generalError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const Divider(height: 1, thickness: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _continueToPrint,
                      child: const Text('Print labels'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
