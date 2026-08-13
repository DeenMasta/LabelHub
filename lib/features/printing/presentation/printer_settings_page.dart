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

/// Configures the direct Bluetooth printers available from the print screen.
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
  List<PrinterDevice> _discoveredDevices = const <PrinterDevice>[];
  String? _defaultProfileId;
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
      final repository = PrinterProfileRepository(database);
      final results = await Future.wait<Object?>(<Future<Object?>>[
        repository.list(),
        repository.defaultProfileId(),
      ]);
      final profiles = results[0]! as List<PrinterProfile>;
      final defaultProfileId = results[1] as String?;
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _defaultProfileId = defaultProfileId;
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

  Future<void> _findPrinters() async {
    setState(() {
      _isDiscovering = true;
      _errorMessage = null;
      _discoveredDevices = const <PrinterDevice>[];
    });
    try {
      final devices = await _printerCatalog.discoverBluetooth();
      if (mounted) {
        setState(() {
          _discoveredDevices = devices;
          if (devices.isEmpty) {
            _errorMessage =
                'No paired Bluetooth printers were found. Pair your printer in Android Settings first, then try again.';
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

  Future<void> _saveProfile(PrinterDevice device) async {
    final database = await ref.read(appDatabaseProvider.future);
    final repository = PrinterProfileRepository(database);

    // Check if it already exists to avoid duplicates
    final existingIndex = _profiles.indexWhere(
      (p) => p.address == device.id.split('#').first,
    );

    if (existingIndex >= 0) {
      // It exists, just make it default
      await repository.setDefault(_profiles[existingIndex].id);
      if (mounted) {
        setState(() {
          _defaultProfileId = _profiles[existingIndex].id;
          _discoveredDevices =
              const <PrinterDevice>[]; // clear scan list on success
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${device.name} is now the default printer.')),
        );
      }
      return;
    }

    final profile = PrinterProfile(
      id: const Uuid().v4(),
      name: device.name,
      address: device.id.split('#').first,
    );
    try {
      await repository.saveProfile(
        id: profile.id,
        name: profile.name,
        address: profile.address,
      );

      // Automatically make the newly added printer the default
      await repository.setDefault(profile.id);

      if (mounted) {
        setState(() {
          _profiles = <PrinterProfile>[..._profiles, profile]
            ..sort(
              (PrinterProfile a, PrinterProfile b) => a.name.compareTo(b.name),
            );
          _errorMessage = null;
          _defaultProfileId = profile.id;
          _discoveredDevices =
              const <PrinterDevice>[]; // clear scan list on success
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer connected successfully.')),
        );
      }
    } on PrinterProfileException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
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
        if (_defaultProfileId == profile.id) {
          _defaultProfileId = null;
        }
      });
    }
  }

  Future<void> _setDefaultProfile(PrinterProfile profile) async {
    final database = await ref.read(appDatabaseProvider.future);
    await PrinterProfileRepository(database).setDefault(profile.id);
    if (mounted) {
      setState(() => _defaultProfileId = profile.id);
    }
  }

  bool _isSaved(PrinterDevice device) => _profiles.any(
    (PrinterProfile profile) => profile.address == device.id.split('#').first,
  );

  @override
  Widget build(BuildContext context) {
    final defaultProfile = _profiles
        .where((p) => p.id == _defaultProfileId)
        .firstOrNull;

    return AppPageContent(
      children: <Widget>[
        const PageHeading(
          eyebrow: 'Hardware',
          title: 'Printer connection',
          description:
              'Pair your Bluetooth label printer in Android settings, then connect it here for offline printing.',
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/printing');
          },
          icon: const Icon(Icons.print_outlined),
          label: const Text('Back to print labels'),
        ),
        const SizedBox(height: 24),

        // Active Printer Status Card (SaaS Hero Card)
        _ActivePrinterCard(
          defaultProfile: defaultProfile,
          isLoading: _isLoading,
        ),

        const SizedBox(height: 24),

        // Setup / Discover Area
        _PrinterDiscoverySection(
          isDiscovering: _isDiscovering,
          discoveredDevices: _discoveredDevices,
          onScan: _findPrinters,
          onConnect: _saveProfile,
          isSaved: _isSaved,
        ),

        if (_profiles.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          _SavedPrintersSection(
            profiles: _profiles,
            defaultProfileId: _defaultProfileId,
            onSetDefault: _setDefaultProfile,
            onDelete: _deleteProfile,
          ),
        ],

        if (_errorMessage != null) ...<Widget>[
          const SizedBox(height: 16),
          _ErrorMessage(message: _errorMessage!),
        ],
      ],
    );
  }

  String _messageFor(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('bluetooth_scan') ||
        msg.contains('bluetooth_connect') ||
        msg.contains('nearby devices permission')) {
      return 'Allow Nearby devices permission to find paired Bluetooth printers, then try again.';
    }
    return 'Bluetooth printers could not be checked. Confirm Bluetooth permission, then try again.';
  }
}

class _ActivePrinterCard extends StatelessWidget {
  const _ActivePrinterCard({
    required this.defaultProfile,
    required this.isLoading,
  });

  final PrinterProfile? defaultProfile;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = defaultProfile != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isConnected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.print_rounded
                        : Icons.print_disabled_rounded,
                    color: isConnected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Active printer',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (isLoading)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (isConnected)
                        Text(
                          defaultProfile!.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        Text(
                          'No printer connected',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isConnected)
                  Chip(
                    label: const Text('Ready'),
                    backgroundColor: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.5),
                    side: BorderSide.none,
                  ),
              ],
            ),
            if (isConnected) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'Bluetooth · ${defaultProfile!.address}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else if (!isLoading) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'Connect a printer below to start printing labels.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrinterDiscoverySection extends StatelessWidget {
  const _PrinterDiscoverySection({
    required this.isDiscovering,
    required this.discoveredDevices,
    required this.onScan,
    required this.onConnect,
    required this.isSaved,
  });

  final bool isDiscovering;
  final List<PrinterDevice> discoveredDevices;
  final VoidCallback onScan;
  final ValueChanged<PrinterDevice> onConnect;
  final bool Function(PrinterDevice) isSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Available printers',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: isDiscovering ? null : onScan,
          icon: isDiscovering
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.bluetooth_searching_rounded),
          label: Text(
            isDiscovering ? 'Scanning nearby devices...' : 'Scan for printers',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (discoveredDevices.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: discoveredDevices.asMap().entries.map((entry) {
                final index = entry.key;
                final device = entry.value;
                final saved = isSaved(device);
                return Column(
                  children: [
                    if (index > 0) const Divider(height: 1, indent: 56),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bluetooth_rounded),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Text('TSPL Printer'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          saved
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: () => onConnect(device),
                                  child: const Text('Connect'),
                                ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _SavedPrintersSection extends StatelessWidget {
  const _SavedPrintersSection({
    required this.profiles,
    required this.defaultProfileId,
    required this.onSetDefault,
    required this.onDelete,
  });

  final List<PrinterProfile> profiles;
  final String? defaultProfileId;
  final ValueChanged<PrinterProfile> onSetDefault;
  final ValueChanged<PrinterProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Saved printers',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: profiles.asMap().entries.map((entry) {
              final index = entry.key;
              final profile = entry.value;
              final isDefault = profile.id == defaultProfileId;

              return Column(
                children: [
                  if (index > 0) const Divider(height: 1, indent: 56),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.print_outlined,
                          color: isDefault ? theme.colorScheme.primary : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                style: TextStyle(
                                  fontWeight: isDefault
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              Text('Bluetooth · ${profile.address}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (String value) {
                            if (value == 'set_active') onSetDefault(profile);
                            if (value == 'remove') onDelete(profile);
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                                if (!isDefault)
                                  const PopupMenuItem<String>(
                                    value: 'set_active',
                                    child: Text('Set Active'),
                                  ),
                                const PopupMenuItem<String>(
                                  value: 'remove',
                                  child: Text('Remove Printer'),
                                ),
                              ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
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
