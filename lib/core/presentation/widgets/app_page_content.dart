import 'package:flutter/material.dart';

/// Keeps feature pages comfortable on phones and productive on wide displays.
class AppPageContent extends StatelessWidget {
  const AppPageContent({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final layout = AppPageLayout.fromWidth(constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                layout.horizontalPadding,
                layout.verticalPadding,
                layout.horizontalPadding,
                layout.bottomPadding,
              ),
              children: children,
            ),
          ),
        );
      },
    );
  }
}

/// The shared width rules for portrait, landscape, tablet, and desktop views.
class AppPageLayout {
  const AppPageLayout({
    required this.maxContentWidth,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.bottomPadding,
  });

  final double maxContentWidth;
  final double horizontalPadding;
  final double verticalPadding;
  final double bottomPadding;

  factory AppPageLayout.fromWidth(double width) {
    if (width < 600) {
      return const AppPageLayout(
        maxContentWidth: double.infinity,
        horizontalPadding: 20,
        verticalPadding: 24,
        bottomPadding: 28,
      );
    }
    if (width < 1024) {
      return const AppPageLayout(
        maxContentWidth: 880,
        horizontalPadding: 32,
        verticalPadding: 28,
        bottomPadding: 36,
      );
    }
    return const AppPageLayout(
      maxContentWidth: 1120,
      horizontalPadding: 48,
      verticalPadding: 32,
      bottomPadding: 44,
    );
  }
}
