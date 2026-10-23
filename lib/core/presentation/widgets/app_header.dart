import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/active_printer_profile_provider.dart';
import '../../../app/theme/app_theme.dart';
import '../../../features/printing/domain/entities/printer_profile.dart';

/// Shared product header used by every primary application screen.
class AppHeader extends ConsumerWidget {
  const AppHeader({
    this.onPrinterPressed,
    this.onSettingsPressed,
    super.key,
  });

  final VoidCallback? onPrinterPressed;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerProfile = ref.watch(activePrinterProfileProvider);
    final profile = printerProfile.when(
      data: (PrinterProfile? profile) => profile,
      loading: () => null,
      error: (_, _) => null,
    );
    return SafeArea(
      bottom: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: <Widget>[
              const _HeaderBrand(),
              const Spacer(),
              _PrinterStatusAction(
                profile: profile,
                isLoading: printerProfile.isLoading,
                onPressed: onPrinterPressed,
              ),
              const SizedBox(width: 4),
              _HeaderAction(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onPressed: onSettingsPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrinterStatusAction extends StatelessWidget {
  const _PrinterStatusAction({
    required this.profile,
    required this.isLoading,
    required this.onPressed,
  });

  final PrinterProfile? profile;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final hasPrinter = profile != null;
    final label = isLoading
        ? 'Checking'
        : hasPrinter
        ? profile!.connectionType.label
        : 'No printer';
    final tooltip = isLoading
        ? 'Checking default printer'
        : hasPrinter
        ? 'Default printer: ${profile!.name} (${profile!.connectionType.label})'
        : 'No default printer configured';

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: hasPrinter ? AppTheme.accentBlue : AppTheme.navy,
          ),
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  hasPrinter ? Icons.print_rounded : Icons.print_disabled_rounded,
                  size: 20,
                ),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _HeaderBrand extends StatelessWidget {
  const _HeaderBrand();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'LabelHub',
      child: Image.asset(
        'assets/labelHub_banner.png',
        width: 120,
        height: 35,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      tooltip: tooltip,
      color: AppTheme.navy,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        padding: const EdgeInsets.all(10),
      ),
    );
  }
}
