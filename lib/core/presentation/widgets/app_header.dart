import 'package:flutter/material.dart';

/// Shared product header used by every primary application screen.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Row(
          children: <Widget>[
            const _BrandMark(),
            const SizedBox(width: 9),
            Text(
              'LabelHub',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            _HeaderAction(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFD9E9E4),
              child: Text(
                'LH',
                style: TextStyle(
                  color: Color(0xFF173326),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFF121C2A),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 25,
        height: 25,
        child: Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onPressed,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Tooltip(message: tooltip, child: Icon(icon, size: 18)),
        ),
      ),
    );
  }
}
