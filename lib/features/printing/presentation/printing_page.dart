import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/printing/label_printer.dart';
import '../../../core/printing/system_pdf_printer.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../../labels/domain/entities/label_layout.dart';
import '../../labels/presentation/widgets/label_layout_selector.dart';
import '../../labels/presentation/widgets/record_selector_card.dart';
import '../../records/data/record_repository.dart';
import '../../records/domain/entities/catalogue_record.dart';
import '../data/pdf_label_document_generator.dart';
import '../data/print_job_repository.dart';
import '../domain/entities/print_job.dart';

class PrintingPage extends ConsumerStatefulWidget {
  const PrintingPage({
    this.initialRecordIds = const <String>[],
    this.initialLayoutId,
    super.key,
  });

  final List<String> initialRecordIds;
  final String? initialLayoutId;

  @override
  ConsumerState<PrintingPage> createState() => _PrintingPageState();
}

class _PrintingPageState extends ConsumerState<PrintingPage> {
  static const _documentGenerator = PdfLabelDocumentGenerator();

  final LabelPrinter _printer = SystemPdfPrinter();
  final Set<String> _selectedRecordIds = <String>{};
  List<CatalogueRecord> _records = const <CatalogueRecord>[];
  List<PrintJob> _printJobs = const <PrintJob>[];
  Object? _loadError;
  String? _printError;
  bool _isLoading = true;
  bool _isPrinting = false;
  int _copies = 1;
  LabelLayout _layout = productLabelLayout;

  @override
  void initState() {
    super.initState();
    _selectedRecordIds.addAll(widget.initialRecordIds);
    _layout = productLabelLayoutForId(widget.initialLayoutId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<CatalogueRecord> get _selectedRecords => _records
      .where((CatalogueRecord record) => _selectedRecordIds.contains(record.id))
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
      final records = await RecordRepository(database).list();
      final printJobs = await PrintJobRepository(database).listRecent();
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records
            .where((CatalogueRecord record) => !record.isArchived)
            .toList();
        _selectedRecordIds.removeWhere(
          (String id) =>
              !_records.any((CatalogueRecord record) => record.id == id),
        );
        _printJobs = printJobs;
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

  void _toggleRecord(CatalogueRecord record, bool selected) {
    setState(() {
      if (selected) {
        _selectedRecordIds.add(record.id);
      } else {
        _selectedRecordIds.remove(record.id);
      }
      _printError = null;
    });
  }

  Future<void> _print() async {
    final records = _selectedRecords;
    if (records.isEmpty || _isPrinting) {
      return;
    }
    setState(() {
      _isPrinting = true;
      _printError = null;
    });

    String? jobId;
    PrintJobRepository? repository;
    try {
      final pdfBytes = await _documentGenerator.generate(
        records: records,
        copies: _copies,
        layout: _layout,
      );
      final database = await ref.read(appDatabaseProvider.future);
      repository = PrintJobRepository(database);
      jobId = const Uuid().v4();
      await repository.create(
        id: jobId,
        printerName: 'System print dialog',
        labelLayoutId: _layout.id,
        recordCount: records.length,
        copies: _copies,
      );
      final device = (await _printer.discover()).single;
      await _printer.connect(device);
      final result = await _printer.printLabels(
        PrintRequest(
          recordIds: records
              .map((CatalogueRecord record) => record.id)
              .toList(),
          copies: _copies,
          pdfBytes: pdfBytes,
          documentName: 'LabelHub product labels',
        ),
      );
      await _printer.disconnect();
      if (!result.succeeded) {
        throw _PrintException(
          result.message ?? 'The system print dialog failed.',
        );
      }
      await repository.markCompleted(jobId);
      await _load();
    } on Exception catch (error) {
      if (jobId != null && repository != null) {
        await repository.markFailed(jobId, error.toString());
      }
      if (mounted) {
        setState(() => _printError = _errorMessage(error));
      }
      await _load();
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  String _errorMessage(Object error) {
    return switch (error) {
      PdfLabelDocumentException exception => exception.message,
      _PrintException exception => exception.message,
      _ => 'The labels could not be prepared for printing. Try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppPageContent(
      children: <Widget>[
        PageHeading(
          eyebrow: 'Output',
          title: 'Print labels',
          description:
              'Generate a physically sized ${_layout.widthMm.toStringAsFixed(0)} × ${_layout.heightMm.toStringAsFixed(0)} mm PDF and hand it to the device print system.',
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
              final selector = RecordSelectorCard(
                title: 'Records to print',
                description:
                    'Choose the active records to include in this job.',
                records: _records,
                selectedRecordIds: _selectedRecordIds,
                onChanged: _toggleRecord,
              );
              final configuration = _PrintConfigurationCard(
                layout: _layout,
                copies: _copies,
                selectedRecordCount: _selectedRecords.length,
                isPrinting: _isPrinting,
                errorMessage: _printError,
                onDecreaseCopies: _copies > 1
                    ? () => setState(() => _copies--)
                    : null,
                onIncreaseCopies: () => setState(() => _copies++),
                onLayoutChanged: (LabelLayout? layout) {
                  if (layout != null) {
                    setState(() {
                      _layout = layout;
                      _printError = null;
                    });
                  }
                },
                onPrint: _selectedRecordIds.isEmpty ? null : _print,
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
          const SizedBox(height: 20),
          _RecentPrintJobsCard(printJobs: _printJobs),
        ],
      ],
    );
  }
}

class _PrintConfigurationCard extends StatelessWidget {
  const _PrintConfigurationCard({
    required this.layout,
    required this.copies,
    required this.selectedRecordCount,
    required this.isPrinting,
    required this.errorMessage,
    required this.onDecreaseCopies,
    required this.onIncreaseCopies,
    required this.onLayoutChanged,
    required this.onPrint,
  });

  final LabelLayout layout;
  final int copies;
  final int selectedRecordCount;
  final bool isPrinting;
  final String? errorMessage;
  final VoidCallback? onDecreaseCopies;
  final VoidCallback onIncreaseCopies;
  final ValueChanged<LabelLayout?> onLayoutChanged;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final labelCount = selectedRecordCount * copies;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Print configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'The system print dialog selects the available printer.',
            ),
            const SizedBox(height: 20),
            LabelLayoutSelector(
              selectedLayout: layout,
              onChanged: onLayoutChanged,
            ),
            const SizedBox(height: 20),
            const Text('Copies per record'),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Decrease copies',
                  onPressed: onDecreaseCopies,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '$copies',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Increase copies',
                  onPressed: onIncreaseCopies,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppTheme.paleBlueSurface,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _PrintSummaryLine(
                      label: 'Layout',
                      value:
                          '${layout.widthMm.toStringAsFixed(0)} × ${layout.heightMm.toStringAsFixed(0)} mm',
                    ),
                    const SizedBox(height: 8),
                    _PrintSummaryLine(
                      label: 'Selected records',
                      value: '$selectedRecordCount',
                    ),
                    const SizedBox(height: 8),
                    _PrintSummaryLine(
                      label: 'Total labels',
                      value: '$labelCount',
                    ),
                    const SizedBox(height: 8),
                    const _PrintSummaryLine(
                      label: 'Output',
                      value: 'PDF via system print dialog',
                    ),
                  ],
                ),
              ),
            ),
            if (errorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              _PrintErrorPanel(message: errorMessage!),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isPrinting ? null : onPrint,
              icon: isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
              label: Text(
                isPrinting ? 'Opening print dialog…' : 'Print labels',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintSummaryLine extends StatelessWidget {
  const _PrintSummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        );
      },
    );
  }
}

class _RecentPrintJobsCard extends StatelessWidget {
  const _RecentPrintJobsCard({required this.printJobs});

  final List<PrintJob> printJobs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Recent print jobs',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (printJobs.isEmpty)
              const Text(
                'No label PDFs have been sent to the print system yet.',
              )
            else
              for (final job in printJobs) ...<Widget>[
                _PrintJobRow(job: job),
                if (job != printJobs.last) const Divider(height: 24),
              ],
          ],
        ),
      ),
    );
  }
}

class _PrintJobRow extends StatelessWidget {
  const _PrintJobRow({required this.job});

  final PrintJob job;

  @override
  Widget build(BuildContext context) {
    final timestamp = job.completedAt ?? job.createdAt;
    final statusColor = job.isCompleted || job.status == 'pending'
        ? AppTheme.blue
        : Theme.of(context).colorScheme.error;
    final statusLabel = switch (job.status) {
      'completed' => 'Sent',
      'pending' => 'Pending',
      _ => 'Failed',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${job.labelCount} labels · ${job.printerName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${job.recordCount} records × ${job.copies} copies · ${_formatTimestamp(timestamp)}',
        ),
        if (job.errorMessage != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(job.errorMessage!, style: TextStyle(color: statusColor)),
        ],
      ],
    );
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
