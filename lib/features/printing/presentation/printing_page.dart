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
    super.key,
  });

  final List<String> initialRecordIds;
  final String? initialLayoutId;

  @override
  ConsumerState<PrintingPage> createState() => _PrintingPageState();
}

class _PrintingPageState extends ConsumerState<PrintingPage> {
  static const _documentGenerator = PdfLabelDocumentGenerator();

  final PrinterCatalog _printerCatalog = PrinterCatalog();
  final Set<String> _selectedRecordIds = <String>{};
  List<PrinterDevice> _availablePrinters = const <PrinterDevice>[];
  List<CatalogueRecord> _records = const <CatalogueRecord>[];
  List<PrintJob> _printJobs = const <PrintJob>[];
  Object? _loadError;
  String? _printError;
  bool _isLoading = true;
  bool _isDiscoveringBluetooth = false;
  bool _isDiscoveringUsb = false;
  bool _isCalibratingMedia = false;
  bool _isPrinting = false;
  int _copies = 1;
  LabelLayout _layout = productLabelLayout;
  PrinterDevice? _selectedPrinter;

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
      final results = await Future.wait<Object>(<Future<Object>>[
        RecordRepository(database).list(),
        PrintJobRepository(database).listRecent(),
        _printerCatalog.initialDevices(),
        PrinterProfileRepository(database).list(),
      ]);
      final records = results[0] as List<CatalogueRecord>;
      final printJobs = results[1] as List<PrintJob>;
      final printers = results[2] as List<PrinterDevice>;
      final printerProfiles = results[3] as List<PrinterProfile>;
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
        _availablePrinters = _mergePrinters(printers);
        _availablePrinters = _mergePrinters(
          printerProfiles
              .map((PrinterProfile profile) => profile.toDevice())
              .toList(),
        );
        _selectedPrinter ??= _availablePrinters.firstOrNull;
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

  List<PrinterDevice> _mergePrinters(List<PrinterDevice> devices) {
    final printers = <PrinterDevice>[..._availablePrinters];
    for (final device in devices) {
      if (printers.any((PrinterDevice printer) => printer.id == device.id)) {
        continue;
      }
      printers.add(device);
    }
    return printers;
  }

  Future<void> _discoverBluetoothPrinters() async {
    if (_isDiscoveringBluetooth) {
      return;
    }
    setState(() {
      _isDiscoveringBluetooth = true;
      _printError = null;
    });
    try {
      final devices = await _printerCatalog.discoverBluetooth();
      if (!mounted) {
        return;
      }
      setState(() => _availablePrinters = _mergePrinters(devices));
      if (devices.isEmpty && mounted) {
        setState(() {
          _printError =
              'No paired Bluetooth printers were found. Pair the printer in Android settings, then try again.';
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _printError = _errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isDiscoveringBluetooth = false);
      }
    }
  }

  Future<void> _discoverUsbPrinters() async {
    if (_isDiscoveringUsb) {
      return;
    }
    setState(() {
      _isDiscoveringUsb = true;
      _printError = null;
    });
    try {
      final devices = await _printerCatalog.discoverUsb();
      if (!mounted) {
        return;
      }
      setState(() => _availablePrinters = _mergePrinters(devices));
      if (devices.isEmpty && mounted) {
        setState(() {
          _printError =
              'No compatible USB printers were found. Connect the printer, then try again.';
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _printError = _errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isDiscoveringUsb = false);
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
      final result = await connectedPrinter.printLabels(
        PrintRequest(
          recordIds: records
              .map((CatalogueRecord record) => record.id)
              .toList(),
          labels: records
              .map(
                (CatalogueRecord record) => PrintLabelData(
                  primaryText: record.values['item_name']?.trim() ?? '-',
                  secondaryText: record.values['price']?.trim() ?? '-',
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

  Future<void> _calibrateTsplMedia() async {
    final selectedPrinter = _selectedPrinter;
    if (_isPrinting ||
        _isCalibratingMedia ||
        selectedPrinter?.protocol != PrinterProtocol.tspl) {
      return;
    }
    setState(() {
      _isCalibratingMedia = true;
      _printError = null;
    });

    LabelPrinter? connectedPrinter;
    try {
      connectedPrinter = _printerCatalog.printerFor(selectedPrinter!);
      final calibratingPrinter = connectedPrinter;
      if (calibratingPrinter is! TsplMediaCalibratingPrinter) {
        throw const ThermalPrintingException(
          'The selected printer does not support TSPL media calibration.',
        );
      }
      await connectedPrinter.connect(selectedPrinter);
      final result = await (calibratingPrinter as TsplMediaCalibratingPrinter)
          .calibrateTsplMedia(
            widthMm: _layout.widthMm,
            heightMm: _layout.heightMm,
          );
      if (!result.succeeded) {
        throw ThermalPrintingException(
          result.message ?? 'The printer could not calibrate the label media.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Media calibrated for ${_layout.widthMm.toStringAsFixed(0)} × ${_layout.heightMm.toStringAsFixed(0)} mm labels.',
            ),
          ),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _printError = _errorMessage(error));
      }
    } finally {
      if (connectedPrinter != null) {
        try {
          await connectedPrinter.disconnect();
        } on Exception {
          // A completed calibration remains valid if the transport closes late.
        }
      }
      if (mounted) {
        setState(() => _isCalibratingMedia = false);
      }
    }
  }

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
              );
              final configuration = _PrintConfigurationCard(
                layout: _layout,
                copies: _copies,
                selectedRecordCount: _selectedRecords.length,
                printers: _availablePrinters,
                selectedPrinter: _selectedPrinter,
                isPrinting: _isPrinting,
                isCalibratingMedia: _isCalibratingMedia,
                isDiscoveringBluetooth: _isDiscoveringBluetooth,
                isDiscoveringUsb: _isDiscoveringUsb,
                errorMessage: _printError,
                onDecreaseCopies: _copies > 1
                    ? () => setState(() => _copies--)
                    : null,
                onIncreaseCopies: () => setState(() => _copies++),
                onPrinterChanged: (PrinterDevice? printer) {
                  if (printer != null) {
                    setState(() {
                      _selectedPrinter = printer;
                      _printError = null;
                    });
                  }
                },
                onDiscoverBluetooth: _discoverBluetoothPrinters,
                onDiscoverUsb: _discoverUsbPrinters,
                onManageProfiles: () => context.go('/settings/printers'),
                onCalibrateTsplMedia: _calibrateTsplMedia,
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
    required this.layout,
    required this.copies,
    required this.selectedRecordCount,
    required this.printers,
    required this.selectedPrinter,
    required this.isPrinting,
    required this.isCalibratingMedia,
    required this.isDiscoveringBluetooth,
    required this.isDiscoveringUsb,
    required this.errorMessage,
    required this.onDecreaseCopies,
    required this.onIncreaseCopies,
    required this.onPrinterChanged,
    required this.onDiscoverBluetooth,
    required this.onDiscoverUsb,
    required this.onManageProfiles,
    required this.onCalibrateTsplMedia,
    required this.onPrint,
  });

  final LabelLayout layout;
  final int copies;
  final int selectedRecordCount;
  final List<PrinterDevice> printers;
  final PrinterDevice? selectedPrinter;
  final bool isPrinting;
  final bool isCalibratingMedia;
  final bool isDiscoveringBluetooth;
  final bool isDiscoveringUsb;
  final String? errorMessage;
  final VoidCallback? onDecreaseCopies;
  final VoidCallback onIncreaseCopies;
  final ValueChanged<PrinterDevice?> onPrinterChanged;
  final VoidCallback onDiscoverBluetooth;
  final VoidCallback onDiscoverUsb;
  final VoidCallback onManageProfiles;
  final VoidCallback onCalibrateTsplMedia;
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
              'Ready to print',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a saved printer. You can add another one from Settings.',
            ),
            const SizedBox(height: 20),
            _PrintJobSummary(
              layout: layout,
              selectedRecordCount: selectedRecordCount,
              labelCount: labelCount,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PrinterDevice>(
              key: ValueKey<String?>(selectedPrinter?.id),
              initialValue: selectedPrinter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Printer',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<PrinterDevice>>[
                for (final printer in printers)
                  DropdownMenuItem<PrinterDevice>(
                    value: printer,
                    child: Text(printer.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: isPrinting || isCalibratingMedia
                  ? null
                  : onPrinterChanged,
            ),
            const SizedBox(height: 8),
            Text(
              _printerHint(selectedPrinter),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (selectedPrinter?.protocol == PrinterProtocol.tspl) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'After loading or changing labels, calibrate once so the printer detects the label gap.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isPrinting || isCalibratingMedia
                    ? null
                    : onCalibrateTsplMedia,
                icon: isCalibratingMedia
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.straighten_rounded),
                label: Text(
                  isCalibratingMedia
                      ? 'Detecting label media…'
                      : 'Calibrate ${layout.widthMm.toStringAsFixed(0)} × ${layout.heightMm.toStringAsFixed(0)} mm labels',
                ),
              ),
            ],
            const SizedBox(height: 4),
            if (selectedPrinter?.kind == PrinterKind.network)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Add or find a printer'),
                subtitle: const Text(
                  'Set up a profile or use a connected printer once.',
                ),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed:
                        isPrinting ||
                            isCalibratingMedia ||
                            isDiscoveringBluetooth
                        ? null
                        : onDiscoverBluetooth,
                    icon: isDiscoveringBluetooth
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bluetooth_searching_rounded),
                    label: Text(
                      isDiscoveringBluetooth
                          ? 'Checking paired printers…'
                          : 'Find paired Bluetooth printers',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        isPrinting || isCalibratingMedia || isDiscoveringUsb
                        ? null
                        : onDiscoverUsb,
                    icon: isDiscoveringUsb
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.usb_rounded),
                    label: Text(
                      isDiscoveringUsb
                          ? 'Checking USB printers…'
                          : 'Find USB printers',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isPrinting || isCalibratingMedia
                        ? null
                        : onManageProfiles,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Set up printer profiles'),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            const Text('Copies for each product'),
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
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Technical output details'),
              children: <Widget>[
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
                        _PrintSummaryLine(
                          label: 'Output',
                          value: _printerOutput(selectedPrinter),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
                isPrinting
                    ? 'Preparing print…'
                    : 'Print $labelCount ${labelCount == 1 ? 'label' : 'labels'}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _printerHint(PrinterDevice? printer) {
    return switch (printer?.kind) {
      PrinterKind.sunmiInner =>
        'Print directly to the compatible Sunmi terminal’s internal printer.',
      PrinterKind.bluetooth =>
        'Only paired Bluetooth printers are shown. Select the matching receipt or label command mode.',
      PrinterKind.usb =>
        'Connect the printer by USB, then select its matching command mode.',
      PrinterKind.network =>
        'Sends directly to the saved network printer profile.',
      _ => 'Open Android’s system print dialog for PDF-capable printers.',
    };
  }

  String _printerOutput(PrinterDevice? printer) {
    return switch (printer?.protocol) {
      PrinterProtocol.escPos => 'Direct raster via ESC/POS',
      PrinterProtocol.tspl => 'Direct raster via TSPL',
      PrinterProtocol.zpl => 'Direct raster via ZPL',
      _ => 'PDF via system print dialog',
    };
  }
}

class _PrintJobSummary extends StatelessWidget {
  const _PrintJobSummary({
    required this.layout,
    required this.selectedRecordCount,
    required this.labelCount,
  });

  final LabelLayout layout;
  final int selectedRecordCount;
  final int labelCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.paleBlueSurface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'This print job',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _PrintSummaryLine(
              label: 'Label size',
              value:
                  '${layout.widthMm.toStringAsFixed(0)} × ${layout.heightMm.toStringAsFixed(0)} mm',
            ),
            const SizedBox(height: 8),
            _PrintSummaryLine(
              label: 'Selected products',
              value: '$selectedRecordCount',
            ),
            const SizedBox(height: 8),
            _PrintSummaryLine(label: 'Labels to print', value: '$labelCount'),
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
    PrinterProtocol.systemPdf => 'PDF',
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
