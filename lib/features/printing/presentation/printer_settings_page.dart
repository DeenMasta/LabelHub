import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/printing/label_printer.dart';
import '../../../core/printing/printer_catalog.dart';
import '../../../core/presentation/widgets/app_page_content.dart';
import '../../../core/presentation/widgets/page_heading.dart';
import '../data/printer_profile_repository.dart';
import '../domain/entities/printer_profile.dart';

/// Configures the direct printers that are available from the print screen.
class PrinterSettingsPage extends ConsumerStatefulWidget {
  const PrinterSettingsPage({this.printerCatalog, super.key});

  final PrinterCatalog? printerCatalog;

  @override
  ConsumerState<PrinterSettingsPage> createState() =>
      _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends ConsumerState<PrinterSettingsPage> {
  late final PrinterCatalog _printerCatalog;
  List<PrinterProfile> _profiles = const <PrinterProfile>[];
  List<PrinterDevice> _pairedDevices = const <PrinterDevice>[];
  String? _errorMessage;
  bool _isLoading = true;
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _printerCatalog = widget.printerCatalog ?? PrinterCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final database = await ref.read(appDatabaseProvider.future);
      final profiles = await PrinterProfileRepository(database).list();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Printer profiles could not be loaded. Try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _findPairedDevices() async {
    setState(() {
      _isDiscovering = true;
      _errorMessage = null;
    });
    try {
      final devices = await _printerCatalog.discoverBluetooth();
      if (mounted) {
        setState(() {
          _pairedDevices = devices;
          if (devices.isEmpty) {
            _errorMessage =
                'No paired Bluetooth printers were found. Pair the printer in Android settings, then try again.';
          }
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isDiscovering = false);
      }
    }
  }

  Future<void> _saveBluetoothProfile(PrinterDevice device) async {
    final database = await ref.read(appDatabaseProvider.future);
    final profile = PrinterProfile(
      id: const Uuid().v4(),
      name: device.name,
      kind: PrinterKind.bluetooth,
      protocol: device.protocol,
      address: device.id.split('#').first,
    );
    try {
      await PrinterProfileRepository(database).saveBluetooth(
        id: profile.id,
        name: profile.name,
        address: profile.address,
        protocol: profile.protocol,
      );
      if (mounted) {
        setState(() {
          _profiles = <PrinterProfile>[..._profiles, profile]
            ..sort(
              (PrinterProfile a, PrinterProfile b) => a.name.compareTo(b.name),
            );
          _errorMessage = null;
        });
      }
    } on PrinterProfileException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    }
  }

  Future<void> _saveNetworkProfile({
    required String name,
    required String host,
    required int port,
    required PrinterProtocol protocol,
  }) async {
    final database = await ref.read(appDatabaseProvider.future);
    final profile = PrinterProfile(
      id: const Uuid().v4(),
      name: name.trim(),
      kind: PrinterKind.network,
      protocol: protocol,
      address: host.trim(),
      port: port,
    );
    try {
      await PrinterProfileRepository(database).saveNetwork(
        id: profile.id,
        name: profile.name,
        host: profile.address,
        port: port,
        protocol: profile.protocol,
      );
      if (mounted) {
        setState(() {
          _profiles = <PrinterProfile>[..._profiles, profile]
            ..sort(
              (PrinterProfile a, PrinterProfile b) => a.name.compareTo(b.name),
            );
          _errorMessage = null;
        });
      }
    } on PrinterProfileException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
      rethrow;
    }
  }

  Future<void> _deleteProfile(PrinterProfile profile) async {
    final database = await ref.read(appDatabaseProvider.future);
    await PrinterProfileRepository(database).delete(profile.id);
    if (mounted) {
      setState(() {
        _profiles = _profiles
            .where((PrinterProfile item) => item.id != profile.id)
            .toList();
      });
    }
  }

  bool _isSaved(PrinterDevice device) => _profiles.any(
    (PrinterProfile profile) =>
        profile.kind == PrinterKind.bluetooth &&
        profile.address == device.id.split('#').first &&
        profile.protocol == device.protocol,
  );

  @override
  Widget build(BuildContext context) {
    return AppPageContent(
      children: <Widget>[
        const PageHeading(
          eyebrow: 'Hardware',
          title: 'Printer settings',
          description:
              'Save paired barcode printers once, then select them from Print labels whenever you need them.',
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => context.go('/printing'),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Back to print labels'),
        ),
        const SizedBox(height: 20),
        _NetworkPrinterSetupCard(onSave: _saveNetworkProfile),
        const SizedBox(height: 20),
        _PairedBluetoothPrintersCard(
          devices: _pairedDevices,
          isDiscovering: _isDiscovering,
          isSaved: _isSaved,
          onFind: _findPairedDevices,
          onSave: _saveBluetoothProfile,
        ),
        const SizedBox(height: 20),
        _SavedPrinterProfilesCard(
          profiles: _profiles,
          isLoading: _isLoading,
          onDelete: _deleteProfile,
        ),
        if (_errorMessage != null) ...<Widget>[
          const SizedBox(height: 16),
          _PrinterSettingsError(message: _errorMessage!),
        ],
      ],
    );
  }

  String _messageFor(Object error) => switch (error) {
    PrinterProfileException exception => exception.message,
    _
        when error.toString().toLowerCase().contains('bluetooth_scan') ||
            error.toString().toLowerCase().contains('bluetooth_connect') ||
            error.toString().toLowerCase().contains(
              'nearby devices permission',
            ) =>
      'Allow Nearby devices permission to find paired Bluetooth printers, then try again.',
    _ =>
      'Bluetooth printers could not be checked. Confirm Bluetooth permission, then try again.',
  };
}

class _NetworkPrinterSetupCard extends StatelessWidget {
  const _NetworkPrinterSetupCard({required this.onSave});

  final Future<void> Function({
    required String name,
    required String host,
    required int port,
    required PrinterProtocol protocol,
  })
  onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Network printer',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Save a printer on your local network for direct offline printing.',
            ),
            const SizedBox(height: 16),
            const Text('ZYWELL ZY909 label printers use TSPL.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showAddNetworkPrinterDialog(context),
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Add network printer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddNetworkPrinterDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final hostController = TextEditingController();
    final portController = TextEditingController(text: '9100');
    var protocol = PrinterProtocol.tspl;
    String? errorMessage;
    var isSaving = false;
    var hasSaved = false;

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
                        labelText: 'Printer name',
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
                            await onSave(
                              name: nameController.text,
                              host: hostController.text,
                              port: port,
                              protocol: protocol,
                            );
                            if (context.mounted) {
                              hasSaved = true;
                              Navigator.pop(context);
                            }
                          } on PrinterProfileException catch (error) {
                            setDialogState(() => errorMessage = error.message);
                          } finally {
                            if (!hasSaved && context.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: Text(isSaving ? 'Saving...' : 'Save profile'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PairedBluetoothPrintersCard extends StatelessWidget {
  const _PairedBluetoothPrintersCard({
    required this.devices,
    required this.isDiscovering,
    required this.isSaved,
    required this.onFind,
    required this.onSave,
  });

  final List<PrinterDevice> devices;
  final bool isDiscovering;
  final bool Function(PrinterDevice device) isSaved;
  final VoidCallback onFind;
  final ValueChanged<PrinterDevice> onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Paired Bluetooth printers',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'LabelHub only shows devices already paired in Android settings.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isDiscovering ? null : onFind,
              icon: isDiscovering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching_rounded),
              label: Text(
                isDiscovering
                    ? 'Checking paired printers…'
                    : 'Find paired printers',
              ),
            ),
            if (devices.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              for (final device in devices) ...<Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bluetooth_rounded),
                  title: Text(device.name),
                  subtitle: Text(_protocolDescription(device.protocol)),
                  trailing: isSaved(device)
                      ? const Chip(label: Text('Saved'))
                      : FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(76, 48),
                          ),
                          onPressed: () => onSave(device),
                          child: const Text('Save'),
                        ),
                ),
                if (device != devices.last) const Divider(height: 16),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _protocolDescription(PrinterProtocol protocol) => switch (protocol) {
    PrinterProtocol.zpl => 'Barcode labels — ZPL',
    PrinterProtocol.tspl => 'Barcode labels — TSPL',
    PrinterProtocol.escPos => 'Receipt printer — ESC/POS',
    PrinterProtocol.systemPdf => 'System PDF printer',
  };
}

class _SavedPrinterProfilesCard extends StatelessWidget {
  const _SavedPrinterProfilesCard({
    required this.profiles,
    required this.isLoading,
    required this.onDelete,
  });

  final List<PrinterProfile> profiles;
  final bool isLoading;
  final ValueChanged<PrinterProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Saved printer profiles',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Saved printers are available from the print configuration.',
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (profiles.isEmpty)
              const Text('No printer profiles saved yet.')
            else
              for (final profile in profiles) ...<Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    profile.kind == PrinterKind.bluetooth
                        ? Icons.bluetooth_rounded
                        : Icons.print_outlined,
                  ),
                  title: Text(profile.name),
                  subtitle: Text(_profileDescription(profile)),
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

  String _profileDescription(PrinterProfile profile) {
    final protocol = switch (profile.protocol) {
      PrinterProtocol.zpl => 'ZPL',
      PrinterProtocol.tspl => 'TSPL',
      PrinterProtocol.escPos => 'ESC/POS',
      PrinterProtocol.systemPdf => 'PDF',
    };
    return profile.kind == PrinterKind.bluetooth
        ? '$protocol · ${profile.address}'
        : '$protocol · ${profile.address}:${profile.port}';
  }
}

class _PrinterSettingsError extends StatelessWidget {
  const _PrinterSettingsError({required this.message});

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
