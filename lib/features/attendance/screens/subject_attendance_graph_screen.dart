import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/attendance_provider.dart';

// ── colours ──────────────────────────────────────────────────────────────────
const _kGreen         = Color(0xFF22C55E);
const _kTextPrimary   = Color(0xFFE5E7EB);
const _kTextSecondary = Color(0xFF9CA3AF);

Color _colorForPercentage(double pct) {
  if (pct >= 80) return Colors.green;
  if (pct >= 75) return Colors.orange;
  if (pct >= 60) return Colors.deepOrange;
  return Colors.red;
}

/// Full-screen analytics screen that shows a running attendance % line chart
/// for a single subject from the very first recorded class day.
class SubjectAttendanceGraphScreen extends StatefulWidget {
  final String subjectName;
  final Color subjectColor;
  final double currentPct;
  final int present;
  final int total;

  const SubjectAttendanceGraphScreen({
    super.key,
    required this.subjectName,
    required this.subjectColor,
    required this.currentPct,
    required this.present,
    required this.total,
  });

  @override
  State<SubjectAttendanceGraphScreen> createState() =>
      _SubjectAttendanceGraphScreenState();
}

class _SubjectAttendanceGraphScreenState
    extends State<SubjectAttendanceGraphScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final provider = context.read<AttendanceProvider>();
    final history = provider.getSubjectDailyHistory(widget.subjectName);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? _kTextPrimary : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subjectName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? _kTextPrimary : Colors.black87,
              ),
            ),
            Text(
              'Attendance Analytics',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _kTextSecondary,
              ),
            ),
          ],
        ),
      ),
      body: history.isEmpty
          ? _buildEmpty(isDark)
          : _buildContent(context, isDark, history),
    );
  }

  // ── empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: widget.subjectColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.show_chart_rounded,
                size: 48, color: widget.subjectColor),
          ),
          const SizedBox(height: 16),
          Text(
            'No data yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? _kTextPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mark some classes to see the trend.',
            style: TextStyle(fontSize: 13, color: _kTextSecondary),
          ),
        ],
      ),
    );
  }

  // ── main content ─────────────────────────────────────────────────────────────
  Widget _buildContent(
      BuildContext context, bool isDark, List<Map<String, dynamic>> history) {
    final color = _colorForPercentage(widget.currentPct);
    final absent = widget.total - widget.present;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // ── Summary cards row ───────────────────────────────────────────
          _buildSummaryRow(isDark, color, absent),
          const SizedBox(height: 20),
          // ── Line chart card ─────────────────────────────────────────────
          _buildChartCard(isDark, history, color),
          const SizedBox(height: 20),
          // ── 75% requirement hint ─────────────────────────────────────────
          _buildRequirementCard(isDark, color),
        ],
      ),
    );
  }

  // ── Summary row ─────────────────────────────────────────────────────────────
  Widget _buildSummaryRow(bool isDark, Color color, int absent) {
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            isDark: isDark,
            icon: Icons.check_circle_rounded,
            iconColor: _kGreen,
            label: 'Present',
            value: '${widget.present}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatPill(
            isDark: isDark,
            icon: Icons.cancel_rounded,
            iconColor: Colors.redAccent,
            label: 'Absent',
            value: '$absent',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatPill(
            isDark: isDark,
            icon: Icons.percent_rounded,
            iconColor: color,
            label: 'Score',
            value: '${widget.currentPct.toStringAsFixed(1)}%',
          ),
        ),
      ],
    );
  }

  // ── Chart card ──────────────────────────────────────────────────────────────
  Widget _buildChartCard(
      bool isDark, List<Map<String, dynamic>> history, Color color) {
    final cardColor =
        isDark ? const Color(0xFF111827) : Colors.white;

    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      final pct = (history[i]['percentage'] as double).clamp(0.0, 100.0);
      spots.add(FlSpot(i.toDouble(), pct));
    }

    final minY = 0.0;
    final maxY = 100.0;

    // Decide how many x labels to show (max 6)
    final labelStep = (history.length / 6).ceil().clamp(1, history.length);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.06))
            : Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 16),
              child: Row(
                children: [
                  Icon(Icons.show_chart_rounded,
                      color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Attendance Trend',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? _kTextPrimary : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Reference line legend
                  _LegendDot(color: Colors.orange.shade300, label: '75%'),
                  const SizedBox(width: 10),
                  _LegendDot(color: color, label: 'You'),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  final animatedSpots = spots
                      .take((spots.length * _anim.value).ceil().clamp(1, spots.length))
                      .toList();

                  return LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (history.length - 1).toDouble(),
                      minY: minY,
                      maxY: maxY,
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.withValues(alpha: 0.12),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 25,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}%',
                              style: const TextStyle(
                                  fontSize: 9, color: _kTextSecondary),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: labelStep.toDouble(),
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= history.length) {
                                return const SizedBox.shrink();
                              }
                              final date =
                                  history[idx]['date'] as DateTime;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat('d/M').format(date),
                                  style: const TextStyle(
                                      fontSize: 8,
                                      color: _kTextSecondary),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 75,
                            color: Colors.orange.shade300
                                .withValues(alpha: 0.7),
                            strokeWidth: 1.2,
                            dashArray: [6, 4],
                          ),
                        ],
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: animatedSpots,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: color,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: history.length <= 20,
                            getDotPainter: (spot, pct, bar, idx) =>
                                FlDotCirclePainter(
                              radius: _touchedIndex == idx ? 5 : 3,
                              color: color,
                              strokeWidth: 1.5,
                              strokeColor: isDark
                                  ? const Color(0xFF111827)
                                  : Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.22),
                                color.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchCallback:
                            (FlTouchEvent event, LineTouchResponse? response) {
                          setState(() {
                            _touchedIndex =
                                response?.lineBarSpots?.first.spotIndex;
                          });
                        },
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFF1E293B),
                          getTooltipItems: (spots) {
                            return spots.map((s) {
                              final idx = s.spotIndex;
                              final data = history[idx];
                              final date = data['date'] as DateTime;
                              final pct =
                                  (data['percentage'] as double)
                                      .toStringAsFixed(1);
                              final p = data['present'] as int;
                              final t = data['total'] as int;
                              return LineTooltipItem(
                                '${DateFormat('d MMM').format(date)}\n',
                                const TextStyle(
                                    color: _kTextSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                                children: [
                                  TextSpan(
                                    text: '$pct%\n',
                                    style: TextStyle(
                                      color: _colorForPercentage(
                                        data['percentage'] as double,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '$p / $t classes',
                                    style: const TextStyle(
                                        color: _kTextSecondary,
                                        fontSize: 10),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Requirement card ─────────────────────────────────────────────────────────
  Widget _buildRequirementCard(bool isDark, Color color) {
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;


    final bool isSafe = widget.currentPct >= 75;
    final int classesNeeded = isSafe
        ? 0
        : (3 * widget.total - 4 * widget.present).ceil().clamp(0, 9999);
    final int canBunk = isSafe
        ? ((4 * widget.present - 3 * widget.total) ~/ 3).clamp(0, 9999)
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.06))
            : Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSafe
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: isSafe ? _kGreen : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Attendance Insight',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? _kTextPrimary : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isSafe) ...[
              Text(
                canBunk > 0
                    ? 'You can skip $canBunk more class${canBunk > 1 ? 'es' : ''} and still stay above 75%.'
                    : 'You are exactly at 75%. Attend all upcoming classes.',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? _kTextSecondary : Colors.black54),
              ),
            ] else ...[
              Text(
                'You need $classesNeeded more present class${classesNeeded > 1 ? 'es' : ''} to reach 75%.',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? _kTextSecondary : Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            // Visual progress toward 75%
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (widget.currentPct / 100).clamp(0.0, 1.0),
                      backgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      color: color,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${widget.currentPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            // 75% marker
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.75 * 0.75 -
                        16,
                  ),
                  Container(
                    width: 1,
                    height: 8,
                    color: Colors.orange.shade300,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '75% target',
                    style: TextStyle(
                        fontSize: 9, color: Colors.orange.shade400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatPill({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF111827) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.06))
            : Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? _kTextPrimary : Colors.black87,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: _kTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: _kTextSecondary)),
      ],
    );
  }
}
