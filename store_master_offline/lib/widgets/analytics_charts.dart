// ============================================================================
// AnalyticsCharts - ویجت نمودارهای سفارشی با CustomPainter
// ============================================================================
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class DualBarChart extends StatelessWidget {
  final List<(String, double)> morning;
  final List<(String, double)> evening;
  final String currency;

  const DualBarChart(
      {super.key,
      required this.morning,
      required this.evening,
      required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxV = [for (final m in morning) m.$2, for (final e in evening) e.$2]
        .fold<double>(1.0, (a, b) => a > b ? a : b);
    final padding = 32.0, gap = 12.0;
    final totalDays = morning.length;
    if (totalDays == 0)
      return const SizedBox(
          height: 180,
          child: Center(
              child: Text('داده‌ای برای نمایش وجود ندارد',
                  style: TextStyle(color: Colors.grey))));
    return SizedBox(
        height: 220,
        child: Padding(
            padding:
                EdgeInsets.fromLTRB(padding, padding, padding, padding + 24),
            child: CustomPaint(
                painter: _DualPainter(
                    morning: morning,
                    evening: evening,
                    maxV: maxV,
                    gap: gap,
                    currency: currency),
                size: Size.infinite)));
  }
}

class _DualPainter extends CustomPainter {
  final List<(String, double)> morning, evening;
  final double maxV, gap;
  final String currency;
  _DualPainter(
      {required this.morning,
      required this.evening,
      required this.maxV,
      required this.gap,
      required this.currency});

  @override
  void paint(Canvas canvas, Size size) {
    final chartH = size.height - 24;
    final totalGroups = morning.length;
    final groupWidth = (size.width - gap * (totalGroups + 1)) / totalGroups;
    final barWidth = (groupWidth - gap) / 2;
    final morningPaint = Paint();
    final eveningPaint = Paint();
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, chartH), Offset(size.width, chartH), axisPaint);

    for (int i = 0; i < morning.length; i++) {
      final morningV = morning[i].$2;
      final eveningV = evening[i].$2;
      final morningH = (morningV / maxV).clamp(0.02, 1.0) * chartH;
      final eveningH = (eveningV / maxV).clamp(0.02, 1.0) * chartH;

      final groupLeft = gap + i * (groupWidth + gap);
      morningPaint.shader = const LinearGradient(
              colors: [Color(0xFFEF6C00), Color(0xFFFFCA28)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter)
          .createShader(
              Rect.fromLTWH(groupLeft, chartH - morningH, barWidth, morningH));
      eveningPaint.shader = const LinearGradient(
              colors: [Color(0xFF3949AB), Color(0xFF7986CB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter)
          .createShader(Rect.fromLTWH(groupLeft + barWidth + gap,
              chartH - eveningH, barWidth, eveningH));

      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(groupLeft, chartH - morningH, barWidth, morningH),
              const Radius.circular(4)),
          morningPaint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(groupLeft + barWidth + gap, chartH - eveningH,
                  barWidth, eveningH),
              const Radius.circular(4)),
          eveningPaint);

      final tp = TextPainter(
          text: TextSpan(
              text: morning[i].$1,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          textDirection: ui.TextDirection.rtl);
      tp.layout();
      tp.paint(canvas,
          Offset(groupLeft + groupWidth / 2 - tp.width / 2, chartH + 6));
    }

    final l = TextPainter(
        text: const TextSpan(
            text: 'صبح',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF6C00))),
        textDirection: ui.TextDirection.rtl)
      ..layout();
    l.paint(canvas, Offset(4, 0));
    final le = TextPainter(
        text: const TextSpan(
            text: 'عصر',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3949AB))),
        textDirection: ui.TextDirection.rtl)
      ..layout();
    le.paint(canvas, Offset(38, 0));
  }

  @override
  bool shouldRepaint(_DualPainter oldDelegate) =>
      oldDelegate.morning != morning || oldDelegate.evening != evening;
}

class CircularProgressRing extends StatelessWidget {
  final double progress;
  final String label;
  final Color color;
  const CircularProgressRing(
      {super.key,
      required this.progress,
      required this.label,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 130,
        height: 130,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
              width: 110,
              height: 110,
              child: CircularProgressIndicator(
                  value: progress.clamp(0, 1),
                  strokeWidth: 10,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(color))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey)),
          ]),
        ]));
  }
}
