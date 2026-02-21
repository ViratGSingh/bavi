import 'package:bavi/services/profile_stats_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MetricChart extends StatelessWidget {
  const MetricChart({
    super.key,
    required this.metric,
    required this.points,
    required this.aggregate,
    required this.onMetricChanged,
    required this.selectedMetric,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final ProfileMetric metric;
  final List<DailyMetricPoint> points;
  final double aggregate;
  final ValueChanged<ProfileMetric> onMetricChanged;
  final ProfileMetric selectedMetric;
  final StatPeriod selectedPeriod;
  final ValueChanged<StatPeriod> onPeriodChanged;

  static const _metricLabels = {
    ProfileMetric.curiosity: 'Curiosity',
    ProfileMetric.depth: 'Depth',
    ProfileMetric.precision: 'Precision',
    ProfileMetric.vocabulary: 'Vocabulary',
  };

  static const _metricIcons = {
    ProfileMetric.curiosity: Icons.psychology_outlined,
    ProfileMetric.depth: Icons.layers_outlined,
    ProfileMetric.precision: Icons.gps_fixed_outlined,
    ProfileMetric.vocabulary: Icons.auto_stories_outlined,
  };

  static const _periodLabels = {
    StatPeriod.daily: 'Daily',
    StatPeriod.weekly: 'Weekly',
    StatPeriod.monthly: 'Monthly',
    StatPeriod.yearly: 'Yearly',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context),
          const SizedBox(height: 16),
          _buildMetricTabs(),
          const SizedBox(height: 20),
          _buildSummary(),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(_buildChartData()),
          ),
          const SizedBox(height: 8),
          _buildAxisLabels(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Statistic',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        GestureDetector(
          onTapDown: (details) {
            _showPeriodMenu(context, details.globalPosition);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _periodLabels[selectedPeriod]!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down,
                    size: 18, color: Color(0xFF374151)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPeriodMenu(BuildContext context, Offset position) {
    final items = StatPeriod.values.map((period) {
      final isSelected = period == selectedPeriod;
      return PopupMenuItem<StatPeriod>(
        value: period,
        child: Text(
          _periodLabels[period]!,
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFF8A2BE2) : const Color(0xFF374151),
          ),
        ),
      );
    }).toList();

    showMenu<StatPeriod>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 80,
        position.dy + 8,
        position.dx + 80,
        position.dy + 200,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      items: items,
    ).then((value) {
      if (value != null) {
        onPeriodChanged(value);
      }
    });
  }

  Widget _buildMetricTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ProfileMetric.values.map((m) {
          final isSelected = m == selectedMetric;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onMetricChanged(m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF8A2BE2).withValues(alpha: 0.1)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF8A2BE2), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _metricIcons[m],
                      size: 16,
                      color: isSelected
                          ? const Color(0xFF8A2BE2)
                          : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _metricLabels[m]!,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Poppins',
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF8A2BE2)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummary() {
    return Row(
      children: [
        Text(
          _formatAggregate(),
          style: const TextStyle(
            fontSize: 28,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _metricUnit(),
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  String _formatAggregate() {
    switch (metric) {
      case ProfileMetric.curiosity:
        return '${aggregate.toStringAsFixed(0)}%';
      case ProfileMetric.depth:
        return aggregate.toStringAsFixed(1);
      case ProfileMetric.precision:
        return aggregate.toStringAsFixed(0);
      case ProfileMetric.vocabulary:
        return '${aggregate.toStringAsFixed(0)}%';
    }
  }

  String _metricUnit() {
    switch (metric) {
      case ProfileMetric.curiosity:
        return 'avg curiosity';
      case ProfileMetric.depth:
        return 'words/message';
      case ProfileMetric.precision:
        return 'unique terms';
      case ProfileMetric.vocabulary:
        return 'vocab diversity';
    }
  }

  LineChartData _buildChartData() {
    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    final maxX = (spots.length - 1).toDouble().clamp(1.0, double.infinity);
    final maxY = spots.fold(0.0, (max, s) => s.y > max ? s.y : max);
    final adjustedMaxY = maxY == 0 ? 10.0 : maxY * 1.2;

    return LineChartData(
      minX: 0,
      maxX: maxX,
      minY: 0,
      maxY: adjustedMaxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: adjustedMaxY / 4,
        getDrawingHorizontalLine: (_) => const FlLine(
          color: Color(0xFFF0F0F0),
          strokeWidth: 0.8,
          dashArray: [6, 4],
        ),
      ),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: const Color(0xFF8A2BE2),
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
              radius: 4,
              color: Colors.white,
              strokeWidth: 2,
              strokeColor: const Color(0xFF8A2BE2),
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF8A2BE2).withValues(alpha: 0.18),
                const Color(0xFF8A2BE2).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
            return LineTooltipItem(
              _formatTooltipValue(s.y),
              const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatTooltipValue(double value) {
    switch (metric) {
      case ProfileMetric.curiosity:
        return '${value.toStringAsFixed(0)}%';
      case ProfileMetric.depth:
        return '${value.toStringAsFixed(1)} words';
      case ProfileMetric.precision:
        return value.toStringAsFixed(0);
      case ProfileMetric.vocabulary:
        return '${value.toStringAsFixed(1)}%';
    }
  }

  Widget _buildAxisLabels() {
    final labels = points.map((p) => p.label).toList();
    // For periods with many labels (daily: 12, yearly: 12), show every other
    final showEveryN = labels.length > 7 ? 2 : 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.asMap().entries.map((e) {
        final show = e.key % showEveryN == 0;
        return Expanded(
          child: Text(
            show ? e.value : '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
              color: Color(0xFF9CA3AF),
            ),
          ),
        );
      }).toList(),
    );
  }
}
