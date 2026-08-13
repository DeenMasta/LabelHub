import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';


import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/printing/label_printer.dart';
import '../../../core/printing/printer_catalog.dart';
import '../../../core/printing/tspl_label_command_encoder.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../../labels/domain/entities/label_layout.dart';
import '../../records/data/record_repository.dart';
import '../../records/domain/entities/catalogue_record.dart';
import '../data/printer_profile_repository.dart';
import '../domain/entities/printer_profile.dart';

class PrintingPage extends ConsumerStatefulWidget {
  const PrintingPage({
    this.initialRecordIds = const <String>[],
    this.initialLayoutId,
    this.initialPrimaryFieldKey = 'item_name',
    this.initialSecondaryFieldKey = 'price',
    this.printerCatalog,
    super.key,
  });

  final List<String> initialRecordIds;
  final String? initialLayoutId;
  final String initialPrimaryFieldKey;
  final String initialSecondaryFieldKey;
  final PrinterCatalog? printerCatalog;

  @override
  ConsumerState<PrintingPage> createState() => _PrintingPageState();
}

class _PrintingPageState extends ConsumerState<PrintingPage> {
  late final PrinterCatalog _printerCatalog;
  final Map<String, int> _recordCopies = <String, int>{};
  List<PrinterDevice> _availablePrinters = const <PrinterDevice>[];
  List<CatalogueRecord> _records = const <CatalogueRecord>[];
  Object? _loadError;
  String? _printError;
  bool _isLoading = true;
  bool _isCalibratingMedia = false;
  bool _isPrinting = false;
  LabelLayout _layout = productLabelLayout;
  PrinterDevice? _selectedPrinter;
  late String _primaryFieldKey;
  late String _secondaryFieldKey;

  @override
  void initState() {
    super.initState();
    _printerCatalog = widget.printerCatalog ?? PrinterCatalog();
    for (final id in widget.initialRecordIds) {
      _recordCopies[id] = 1;
    }
    _layout = productLabelLayoutForId(widget.initialLayoutId);
    _primaryFieldKey = widget.initialPrimaryFieldKey;
    _secondaryFieldKey = widget.initialSecondaryFieldKey;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<CatalogueRecord> get _selectedRecords => _records
      .where((CatalogueRecord record) => (_recordCopies[record.id] ?? 0) > 0)
      .toList();

  Future<void> _load() async {
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
      final records = results[0]! as List<CatalogueRecord>;
      final profiles = results[1]! as List<PrinterProfile>;
      final defaultProfileId = results[2] as String?;
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records
            .where((CatalogueRecord record) => !record.isArchived)
            .toList();
        _recordCopies.removeWhere(
          (String id, _) =>
              !_records.any((CatalogueRecord record) => record.id == id),
        );
        _availablePrinters = profiles
            .map((PrinterProfile profile) => profile.toDevice())
            .toList();
        final selectedPrinterIndex = _availablePrinters.indexWhere(
          (PrinterDevice printer) => printer.id == _selectedPrinter?.id,
        );
        if (selectedPrinterIndex >= 0) {
          _selectedPrinter = _availablePrinters[selectedPrinterIndex];
        } else {
          _selectedPrinter = null;
          for (var index = 0; index < profiles.length; index++) {
            final profile = profiles[index];
            if (profile.id == defaultProfileId) {
              _selectedPrinter = _availablePrinters[index];
              break;
            }
          }
        }
      });
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

  void _updateCopies(CatalogueRecord record, int copies) {
    setState(() {
      if (copies <= 0) {
        _recordCopies.remove(record.id);
      } else {
        _recordCopies[record.id] = copies;
      }
      _printError = null;
    });
  }

  Future<void> _print() async {
    final records = _selectedRecords;
    final selectedPrinter = _selectedPrinter;
    if (records.isEmpty ||
        _isPrinting ||
        _isCalibratingMedia ||
        selectedPrinter == null) {
      return;
    }
    setState(() {
      _isPrinting = true;
      _printError = null;
    });

    LabelPrinter? connectedPrinter;
    try {
      connectedPrinter = _printerCatalog.bluetoothPrinter;
      await connectedPrinter.connect(selectedPrinter);
      await _calibrateBeforePrinting(connectedPrinter, selectedPrinter);
      final result = await connectedPrinter.printLabels(
        PrintRequest(
          recordIds: records
              .map((CatalogueRecord record) => record.id)
              .toList(),
          labels: records
              .map(
                (CatalogueRecord record) => PrintLabelData(
                  primaryText: _fieldValue(record, _primaryFieldKey),
                  secondaryText: _fieldValue(record, _secondaryFieldKey),
                  barcodeValue: record.barcodeValue,
                  copies: _recordCopies[record.id] ?? 1,
                ),
              )
              .toList(),
          labelWidthMm: _layout.widthMm,
          labelHeightMm: _layout.heightMm,
        ),
      );
      if (!result.succeeded) {
        throw _PrintException(
          result.message ?? 'The printer could not complete the print job.',
        );
      }
      await _load();
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _printError = _errorMessage(error));
      }
      await _load();
    } finally {
      if (connectedPrinter != null) {
        try {
          await connectedPrinter.disconnect();
        } on Exception {
          // The print outcome has already been processed; a best-effort socket
          // close must not mask it.
        }
      }
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _calibrateBeforePrinting(
    LabelPrinter printer,
    PrinterDevice selectedPrinter,
  ) async {
    if (printer is! TsplMediaCalibratingPrinter) {
      return;
    }
    final calibratingPrinter = printer as TsplMediaCalibratingPrinter;
    if (mounted) {
      setState(() => _isCalibratingMedia = true);
    }
    try {
      final result = await calibratingPrinter.calibrateTsplMedia(
        widthMm: _layout.widthMm,
        heightMm: _layout.heightMm,
      );
      if (!result.succeeded) {
        throw TsplPrintingException(
          result.message ?? 'The printer could not calibrate the label media.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCalibratingMedia = false);
      }
    }
  }

  String _fieldValue(CatalogueRecord record, String fieldKey) =>
      record.values[fieldKey]?.trim() ?? '';

  String _errorMessage(Object error) {
    final technicalMessage = error.toString().toLowerCase();
    if (technicalMessage.contains('bluetooth_scan') ||
        technicalMessage.contains('bluetooth_connect') ||
        technicalMessage.contains('nearby devices permission')) {
      return 'Allow Nearby devices permission to use paired Bluetooth printers, then try again.';
    }
    return switch (error) {
      TsplPrintingException exception => exception.message,
      PrinterProfileException exception => exception.message,
      PlatformException exception =>
        exception.message ?? 'The selected printer could not be reached.',
      _PrintException exception => exception.message,
      _ => 'The labels could not be prepared for printing. Try again.',
    };
  }

  Future<void> _managePrinterProfiles() async {
    await context.push('/settings/printers');
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageContent(
      children: <Widget>[
        PageHeading(
          eyebrow: 'Output',
          title: 'Print labels',
          description: 'Review the labels, choose where they go, then print.',
        ),
        const SizedBox(height: 20),
        if (_isLoading)
          const _PrintingLoadingPanel()
        else if (_loadError != null)
          _PrintingLoadError(onRetry: _load)
        else if (_records.isEmpty)
          _NoRecordsToPrint(onImport: () => context.go('/imports'))
        else ...<Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final selector = _RecordSelectionList(
                records: _records,
                recordCopies: _recordCopies,
                onUpdateCopies: _updateCopies,
                onSelectAll: () {
                  setState(() {
                    for (final record in _records) {
                      if (!_recordCopies.containsKey(record.id) ||
                          _recordCopies[record.id]! <= 0) {
                        _recordCopies[record.id] = 1;
                      }
                    }
                    _printError = null;
                  });
                },
                onClearSelection: () {
                  setState(() {
                    _recordCopies.clear();
                    _printError = null;
                  });
                },
              );
              final totalLabels = _recordCopies.values.fold<int>(
                0,
                (sum, count) => sum + count,
              );
              final configuration = _PrintConfigurationCard(
                totalLabels: totalLabels,
                hasDefaultPrinter: _selectedPrinter != null,
                isPrinting: _isPrinting,
                isCalibratingMedia: _isCalibratingMedia,
                errorMessage: _printError,
                onManageProfiles: _managePrinterProfiles,
                onPrint: _recordCopies.isEmpty || _selectedPrinter == null
                    ? null
                    : _print,
              );
              if (constraints.maxWidth >= 840) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 4, child: selector),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: configuration),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  selector,
                  const SizedBox(height: 16),
                  configuration,
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _RecordSelectionList extends StatelessWidget {
  const _RecordSelectionList({
    required this.records,
    required this.recordCopies,
    required this.onUpdateCopies,
    required this.onSelectAll,
    required this.onClearSelection,
  });

  final List<CatalogueRecord> records;
  final Map<String, int> recordCopies;
  final void Function(CatalogueRecord record, int copies) onUpdateCopies;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final selectedCount = recordCopies.values.where((c) => c > 0).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Choose labels to print',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$selectedCount of ${records.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Set the quantity for each product you want to print.',
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: onSelectAll,
                    icon: const Icon(Icons.done_all_rounded),
                    label: Text('Select all ${records.length}'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: selectedCount == 0 ? null : onClearSelection,
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final record = records[index];
                final copies = recordCopies[record.id] ?? 0;
                final isSelected = copies > 0;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${record.reference} · ${record.barcodeValue}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                        onPressed: isSelected
                            ? () => onUpdateCopies(record, copies - 1)
                            : null,
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '$copies',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () => onUpdateCopies(record, copies + 1),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintConfigurationCard extends StatelessWidget {
  const _PrintConfigurationCard({
    required this.totalLabels,
    required this.hasDefaultPrinter,
    required this.isPrinting,
    required this.isCalibratingMedia,
    required this.errorMessage,
    required this.onManageProfiles,
    required this.onPrint,
  });

  final int totalLabels;
  final bool hasDefaultPrinter;
  final bool isPrinting;
  final bool isCalibratingMedia;
  final String? errorMessage;
  final VoidCallback onManageProfiles;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Print Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (!hasDefaultPrinter) ...<Widget>[
              const Text(
                'Set a default printer in Settings before printing labels.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isPrinting || isCalibratingMedia
                    ? null
                    : onManageProfiles,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open printer settings'),
              ),
            ],
            if (errorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              _PrintErrorPanel(message: errorMessage!),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isPrinting || isCalibratingMedia ? null : onPrint,
              icon: isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
              label: Text(
                isCalibratingMedia
                    ? 'Calibrating label media…'
                    : isPrinting
                    ? 'Preparing print…'
                    : 'Print $totalLabels ${totalLabels == 1 ? 'label' : 'labels'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintErrorPanel extends StatelessWidget {
  const _PrintErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _PrintingLoadingPanel extends StatelessWidget {
  const _PrintingLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _PrintingLoadError extends StatelessWidget {
  const _PrintingLoadError({required this.onRetry});

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
              'Printing data could not be loaded',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Try again. Your records and print history have not been changed.',
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

class _NoRecordsToPrint extends StatelessWidget {
  const _NoRecordsToPrint({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: AppTheme.navy,
            ),
            const SizedBox(height: 12),
            Text(
              'Import active records before printing',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Archived records are intentionally excluded from print jobs.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import CSV'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintException implements Exception {
  const _PrintException(this.message);

  final String message;
}
