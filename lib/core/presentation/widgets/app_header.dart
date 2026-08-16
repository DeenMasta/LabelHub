import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

/// Shared product header used by every primary application screen.
class AppHeader extends StatelessWidget {
  const AppHeader({this.onSettingsPressed, super.key});

  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
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
