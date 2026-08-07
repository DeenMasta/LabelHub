import 'dart:math' as math;

import 'package:flutter/material.dart';

class PrimaryNavigationDestination {
  const PrimaryNavigationDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Reusable five-item navigation with a central primary dashboard action.
class PrimaryNavigationBar extends StatelessWidget {
  const PrimaryNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<PrimaryNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    assert(
      destinations.length == 5,
      'Primary navigation has five destinations.',
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8ECEA))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List<Widget>.generate(destinations.length, (
                  int index,
                ) {
                  if (index == 2) {
                    return const SizedBox(width: 48);
                  }
                  return _NavigationButton(
                    destination: destinations[index],
                    selected: index == selectedIndex,
                    onPressed: () => onSelected(index),
                  );
                }),
              ),
              Transform.translate(
                offset: const Offset(0, -18),
                child: _PrimaryNavigationAction(
                  destination: destinations[2],
                  selected: selectedIndex == 2,
                  onPressed: () => onSelected(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final PrimaryNavigationDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF121C2A) : const Color(0xFF7D8782);
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: IconButton(
        tooltip: destination.label,
        onPressed: onPressed,
        icon: Icon(destination.icon, color: color, size: 22),
      ),
    );
  }
}

class _PrimaryNavigationAction extends StatelessWidget {
  const _PrimaryNavigationAction({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final PrimaryNavigationDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: IconButton(
        tooltip: destination.label,
        onPressed: onPressed,
        iconSize: 48,
        icon: Transform.rotate(
          angle: math.pi / 4,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF121C2A),
              borderRadius: BorderRadius.all(Radius.circular(10)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x330B1220),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
