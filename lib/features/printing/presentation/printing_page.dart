import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/printing/label_printer.dart';
import '../../../core/printing/printer_catalog.dart';
import '../../../core/printing/thermal_pdf_rasterizer.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../../labels/domain/entities/label_layout.dart';
import '../../labels/presentation/widgets/record_selector_card.dart';
import '../../records/data/record_repository.dart';
import '../../records/domain/entities/catalogue_record.dart';
import '../data/pdf_label_document_generator.dart';
import '../data/print_job_repository.dart';
import '../data/printer_profile_repository.dart';
import '../domain/entities/print_job.dart';
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
  static const _documentGenerator = PdfLabelDocumentGenerator();

  late final PrinterCatalog _printerCatalog;
  final Set<String> _selectedRecordIds = <String>{};
  List<PrinterDevice> _availablePrinters = const <PrinterDevice>[];
  List<CatalogueRecord> _records = const <CatalogueRecord>[];
  List<PrintJob> _printJobs = const <PrintJob>[];
  Object? _loadError;
  String? _printError;
  bool _isLoading = true;
  bool _isCalibratingMedia = false;
  bool _isPrinting = false;
  int _copies = 1;
  LabelLayout _layout = productLabelLayout;
  PrinterDevice? _selectedPrinter;
  late String _primaryFieldKey;
  late String _secondaryFieldKey;

  @override
  void initState() {
    super.initState();
    _printerCatalog = widget.printerCatalog ?? PrinterCatalog();
    _selectedRecordIds.addAll(widget.initialRecordIds);
    _layout = productLabelLayoutForId(widget.initialLayoutId);
    _primaryFieldKey = widget.initialPrimaryFieldKey;
    _secondaryFieldKey = widget.initialSecondaryFieldKey;
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
      final printerProfiles = PrinterProfileRepository(database);
      final results = await Future.wait<Object?>(<Future<Object?>>[
        RecordRepository(database).list(),
        PrintJobRepository(database).listRecent(),
        printerProfiles.list(),
        printerProfiles.defaultProfileId(),
      ]);
      final records = results[0]! as List<CatalogueRecord>;
      final printJobs = results[1]! as List<PrintJob>;
      final profiles = results[2]! as List<PrinterProfile>;
      final defaultProfileId = results[3] as String?;
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

    String? jobId;
    PrintJobRepository? repository;
    LabelPrinter? connectedPrinter;
    try {
      final pdfBytes = await _documentGenerator.generate(
        records: records,
        copies: _copies,
        layout: _layout,
        primaryFieldKey: _primaryFieldKey,
        secondaryFieldKey: _secondaryFieldKey,
      );
      final database = await ref.read(appDatabaseProvider.future);
      repository = PrintJobRepository(database);
      jobId = const Uuid().v4();
      await repository.create(
        id: jobId,
        printerName: selectedPrinter.name,
        labelLayoutId: _layout.id,
        recordCount: records.length,
        copies: _copies,
      );
      connectedPrinter = _printerCatalog.printerFor(selectedPrinter);
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
                ),
              )
              .toList(),
          copies: _copies,
          pdfBytes: pdfBytes,
          documentName: 'LabelHub product labels',
          labelWidthMm: _layout.widthMm,
          labelHeightMm: _layout.heightMm,
        ),
      );
      if (!result.succeeded) {
        throw _PrintException(
          result.message ?? 'The printer could not complete the print job.',
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
      if (connectedPrinter != null) {
        try {
          await connectedPrinter.disconnect();
        } on Exception {
          // The print outcome has already been persisted; a best-effort socket
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
    if (selectedPrinter.protocol != PrinterProtocol.tspl) {
      return;
    }
    if (printer is! TsplMediaCalibratingPrinter) {
      throw const ThermalPrintingException(
        'The selected printer does not support automatic TSPL media calibration.',
      );
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
        throw ThermalPrintingException(
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
      PdfLabelDocumentException exception => exception.message,
      ThermalPrintingException exception => exception.message,
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
              final selector = RecordSelectorCard(
                title: widget.initialRecordIds.isEmpty
                    ? 'Choose labels to print'
                    : 'Labels selected from preview',
                description: widget.initialRecordIds.isEmpty
                    ? 'Select the active records to include in this job.'
                    : 'Your preview selection is ready. Change it only if needed.',
                records: _records,
                selectedRecordIds: _selectedRecordIds,
                onChanged: _toggleRecord,
                onSelectAll: () {
                  setState(() {
                    _selectedRecordIds.addAll(
                      _records.map((CatalogueRecord record) => record.id),
                    );
                    _printError = null;
                  });
                },
                onClearSelection: () {
                  setState(() {
                    _selectedRecordIds.clear();
                    _printError = null;
                  });
                },
              );
              final configuration = _PrintConfigurationCard(
                copies: _copies,
                selectedRecordCount: _selectedRecords.length,
                hasDefaultPrinter: _selectedPrinter != null,
                isPrinting: _isPrinting,
                isCalibratingMedia: _isCalibratingMedia,
                errorMessage: _printError,
                onDecreaseCopies: _copies > 1
                    ? () => setState(() => _copies--)
                    : null,
                onIncreaseCopies: () => setState(() => _copies++),
                onManageProfiles: _managePrinterProfiles,
                onPrint: _selectedRecordIds.isEmpty || _selectedPrinter == null
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
          const SizedBox(height: 20),
          _RecentPrintJobsCard(printJobs: _printJobs),
        ],
      ],
    );
  }
}

class _PrintConfigurationCard extends StatelessWidget {
  const _PrintConfigurationCard({
    required this.copies,
    required this.selectedRecordCount,
    required this.hasDefaultPrinter,
    required this.isPrinting,
    required this.isCalibratingMedia,
    required this.errorMessage,
    required this.onDecreaseCopies,
    required this.onIncreaseCopies,
    required this.onManageProfiles,
    required this.onPrint,
  });

  final int copies;
  final int selectedRecordCount;
  final bool hasDefaultPrinter;
  final bool isPrinting;
  final bool isCalibratingMedia;
  final String? errorMessage;
  final VoidCallback? onDecreaseCopies;
  final VoidCallback onIncreaseCopies;
  final VoidCallback onManageProfiles;
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
              'Copies for each product',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text('Each selected product prints this many labels.'),
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
            if (!hasDefaultPrinter) ...<Widget>[
              const SizedBox(height: 20),
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
                    : 'Print $labelCount ${labelCount == 1 ? 'label' : 'labels'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The profile screen now owns this workflow. It remains temporarily while
// preserving the existing network-profile dialog during the settings migration.
// ignore: unused_element
class _PrinterProfilesCard extends StatelessWidget {
  const _PrinterProfilesCard({
    required this.profiles,
    required this.onSaveNetwork,
    required this.onDelete,
  });

  final List<PrinterProfile> profiles;
  final Future<void> Function({
    required String name,
    required String host,
    required int port,
    required PrinterProtocol protocol,
  })
  onSaveNetwork;
  final Future<void> Function(PrinterProfile profile) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Printer profiles',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showNetworkProfileDialog(context),
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Add network printer'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Save a TCP printer address and its command language for offline direct printing.',
            ),
            const SizedBox(height: 12),
            if (profiles.isEmpty)
              const Text('No network printer profiles have been saved yet.')
            else
              for (final profile in profiles) ...<Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.print_outlined),
                  title: Text(profile.name),
                  subtitle: Text(
                    '${profile.address}:${profile.port} · ${_protocolLabel(profile.protocol)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete ${profile.name}',
                    onPressed: () => onDelete(profile),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
                if (profile != profiles.last) const Divider(height: 16),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _showNetworkProfileDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final hostController = TextEditingController();
    final portController = TextEditingController(text: '9100');
    var protocol = PrinterProtocol.zpl;
    String? errorMessage;
    var isSaving = false;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add network printer'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Profile name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hostController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'IP address or host name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'TCP port'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PrinterProtocol>(
                      initialValue: protocol,
                      decoration: const InputDecoration(
                        labelText: 'Command language',
                      ),
                      items: const <DropdownMenuItem<PrinterProtocol>>[
                        DropdownMenuItem(
                          value: PrinterProtocol.zpl,
                          child: Text('ZPL'),
                        ),
                        DropdownMenuItem(
                          value: PrinterProtocol.tspl,
                          child: Text('TSPL'),
                        ),
                        DropdownMenuItem(
                          value: PrinterProtocol.escPos,
                          child: Text('ESC/POS'),
                        ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (PrinterProtocol? value) {
                              if (value != null) {
                                setDialogState(() => protocol = value);
                              }
                            },
                    ),
                    if (errorMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final port = int.tryParse(portController.text.trim());
                          if (port == null) {
                            setDialogState(
                              () => errorMessage = 'Enter a valid TCP port.',
                            );
                            return;
                          }
                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });
                          try {
                            await onSaveNetwork(
                              name: nameController.text,
                              host: hostController.text,
                              port: port,
                              protocol: protocol,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } on PrinterProfileException catch (error) {
                            setDialogState(() => errorMessage = error.message);
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: Text(isSaving ? 'Saving…' : 'Save profile'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    hostController.dispose();
    portController.dispose();
  }

  String _protocolLabel(PrinterProtocol protocol) => switch (protocol) {
    PrinterProtocol.zpl => 'ZPL',
    PrinterProtocol.tspl => 'TSPL',
    PrinterProtocol.escPos => 'ESC/POS',
  };
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
