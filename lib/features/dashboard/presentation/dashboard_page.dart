import 'package:flutter/material.dart';

import '../../../core/presentation/widgets/app_page_content.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const _screenBackground = Colors.white;
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _screenBackground,
      child: const AppPageContent(
        children: <Widget>[
          _DashboardHeader(),
          SizedBox(height: 16),
          _DashboardTabs(),
          SizedBox(height: 20),
          _DashboardMetrics(),
          SizedBox(height: 20),
          _ChartCard(),
          SizedBox(height: 20),
          _LabelLayoutsPanel(),
        ],
      ),
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics();

  @override
  Widget build(BuildContext context) {
    const cards = <Widget>[
      _MetricCard(
        label: 'Print Jobs',
        value: '12',
        detail: 'recent',
        icon: Icons.print_outlined,
        tint: Color(0xFF26394B),
      ),
      _MetricCard(
        label: 'Total Printed Labels',
        value: '6,500',
        detail: 'all time',
        icon: Icons.local_offer_outlined,
        tint: Color(0xFF26394B),
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[cards[0], SizedBox(height: 12), cards[1]],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: cards[0]),
            SizedBox(width: 16),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Print Overview',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.search_rounded),
          color: const Color(0xFF77807B),
          tooltip: 'Search records',
        ),
      ],
    );
  }
}

class _DashboardTabs extends StatelessWidget {
  const _DashboardTabs();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        _DashboardTab(label: 'Today'),
        SizedBox(width: 26),
        _DashboardTab(label: 'This week', selected: true),
        SizedBox(width: 26),
        _DashboardTab(label: 'This month'),
      ],
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF121C2A) : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF121C2A)
                  : const Color(0xFFA1AAA5),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF121C2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: const Color(0xFFB1BBC4)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Labels Printed per Day',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _PeriodSelector(),
              ],
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 176, child: _WeeklyBarChart()),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'This week',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, size: 17),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart();

  static const _days = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _values = <double>[.44, .68, .53, .82, .64, .94, .58];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedGridPainter(),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List<Widget>.generate(_days.length, (int index) {
            return Expanded(
              child: _ChartBar(
                day: _days[index],
                value: _values[index],
                isDark: index.isOdd,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.day,
    required this.value,
    required this.isDark,
  });

  final String day;
  final double value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const labelHeight = 22.0;
        final barHeight = (constraints.maxHeight - labelHeight - 6) * value;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Container(
              height: barHeight,
              width: 18,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF121C2A)
                    : const Color(0xFFBFDBFE),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              day,
              style: const TextStyle(fontSize: 10, color: Color(0xFF758078)),
            ),
          ],
        );
      },
    );
  }
}

class _DashedGridPainter extends CustomPainter {
  const _DashedGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCE2DF)
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 4.0;

    for (final multiplier in <double>[.2, .45, .7]) {
      final y = size.height * multiplier;
      for (double x = 0; x < size.width; x += dashWidth + dashSpace) {
        canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGridPainter oldDelegate) => false;
}

class _LabelLayoutsPanel extends StatelessWidget {
  const _LabelLayoutsPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF292D2D),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Label Layouts',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const _BarcodeFormatSelector(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const <Widget>[
                  _LabelPreviewCard(size: '50 × 30mm', width: 136),
                  SizedBox(width: 12),
                  _LabelPreviewCard(size: '60 × 40mm', width: 150),
                  SizedBox(width: 12),
                  _LabelPreviewCard(size: '100 × 50mm', width: 176),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarcodeFormatSelector extends StatelessWidget {
  const _BarcodeFormatSelector();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF3C4241),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Code 128',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelPreviewCard extends StatelessWidget {
  const _LabelPreviewCard({required this.size, required this.width});

  final String size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                size,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6B7470),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const _BarcodePlaceholder(),
              const SizedBox(height: 8),
              const Text(
                'Product Name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              const Text(
                'SOH',
                style: TextStyle(fontSize: 10, color: Color(0xFF727B76)),
              ),
              const Spacer(),
              const Text(
                '\$19.99',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodePlaceholder extends StatelessWidget {
  const _BarcodePlaceholder();

  @override
  Widget build(BuildContext context) {
    const bars = <double>[2, 1, 1, 3, 1, 2, 1, 2, 3, 1, 1, 2, 1, 3, 1, 2, 2, 1];
    return SizedBox(
      height: 27,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final width in bars) ...<Widget>[
            SizedBox(
              width: width,
              child: const ColoredBox(color: Color(0xFF1E2421)),
            ),
            const SizedBox(width: 1),
          ],
        ],
      ),
    );
  }
}
