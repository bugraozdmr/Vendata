import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/chart_config.dart';
import '../../domain/models/query_result.dart';

class InteractiveChart extends StatelessWidget {
  final QueryResult result;
  final ChartConfig config;
  final ValueChanged<ChartConfig> onConfigChanged;

  const InteractiveChart({
    super.key,
    required this.result,
    required this.config,
    required this.onConfigChanged,
  });

  static const List<Color> _palette = [
    AppColors.accent,
    AppColors.primary,
    Color(0xFF26A669),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final labelIdx = result.columns.indexOf(config.labelColumn);
    final valIdx = result.columns.indexOf(config.valueColumn);

    if (labelIdx == -1 || valIdx == -1) {
      return Center(
        child: Text(
          'Grafik için sütun seçin.',
          style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final dataPoints = <_ChartDataPoint>[];
    for (final row in result.rows) {
      if (labelIdx >= row.length || valIdx >= row.length) continue;
      final label = row[labelIdx]?.toString() ?? '—';
      final rawVal = row[valIdx];
      final val = (rawVal is num) ? rawVal.toDouble() : (double.tryParse(rawVal?.toString() ?? '') ?? 0.0);
      dataPoints.add(_ChartDataPoint(label: label, value: val));
    }

    final limitedPoints = dataPoints.take(config.maxItems).toList();

    return Column(
      children: [
        _buildControls(context),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: limitedPoints.isEmpty
                ? Center(
                    child: Text(
                      'Sayısal veri bulunamadı.',
                      style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
                    ),
                  )
                : _renderChart(limitedPoints),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Kategori (X)',
                  value: config.labelColumn,
                  items: result.columns,
                  onChanged: (val) {
                    if (val != null) {
                      onConfigChanged(config.copyWith(labelColumn: val));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  label: 'Değer (Y)',
                  value: config.valueColumn,
                  items: result.columns,
                  onChanged: (val) {
                    if (val != null) {
                      onConfigChanged(config.copyWith(valueColumn: val));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Grafik Türü',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildTypeChip('Çubuk', ChartType.bar, Icons.bar_chart_rounded),
              const SizedBox(width: 8),
              _buildTypeChip('Çizgi', ChartType.line, Icons.show_chart_rounded),
              const SizedBox(width: 8),
              _buildTypeChip('Pasta', ChartType.pie, Icons.pie_chart_outline_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, ChartType type, IconData icon) {
    final isSelected = config.type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onConfigChanged(config.copyWith(type: type)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.cardMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.cardMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
              isExpanded: true,
              dropdownColor: Colors.white,
              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
              items: items.map((col) {
                return DropdownMenuItem(
                  value: col,
                  child: Text(col, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _renderChart(List<_ChartDataPoint> points) {
    switch (config.type) {
      case ChartType.bar:
        return _buildBarChart(points);
      case ChartType.line:
        return _buildLineChart(points);
      case ChartType.pie:
        return _buildPieChart(points);
    }
  }

  Widget _buildBarChart(List<_ChartDataPoint> points) {
    final maxY = points.map((p) => p.value).fold<double>(0.0, max) * 1.15;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY <= 0 ? 10 : maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            tooltipBorderRadius: BorderRadius.circular(12),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = points[group.x.toInt()];
              return BarTooltipItem(
                '${p.label}\n${p.value.toStringAsFixed(1)}',
                GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                final interval = (points.length / 5).ceil().clamp(1, 999);
                if (points.length > 5 && idx % interval != 0) {
                  return const SizedBox.shrink();
                }
                final label = points[idx].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label.length > 7 ? '${label.substring(0, 6)}…' : label,
                    style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, meta) {
                return Text(
                  _compactNumber(val),
                  style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 11),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => const FlLine(
            color: AppColors.border,
            strokeWidth: 0.8,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(points.length, (idx) {
          final p = points[idx];
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: p.value,
                color: _palette[idx % _palette.length],
                width: points.length > 10 ? 12 : 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLineChart(List<_ChartDataPoint> points) {
    final maxY = points.map((p) => p.value).fold<double>(0.0, max) * 1.15;

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            tooltipBorderRadius: BorderRadius.circular(12),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final p = points[spot.x.toInt()];
                return LineTooltipItem(
                  '${p.label}\n${p.value.toStringAsFixed(1)}',
                  GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => const FlLine(
            color: AppColors.border,
            strokeWidth: 0.8,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                final interval = (points.length / 5).ceil().clamp(1, 999);
                if (points.length > 5 && idx % interval != 0) {
                  return const SizedBox.shrink();
                }
                final label = points[idx].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label.length > 7 ? '${label.substring(0, 6)}…' : label,
                    style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, meta) {
                return Text(
                  _compactNumber(val),
                  style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 11),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(points.length, (idx) {
              return FlSpot(idx.toDouble(), points[idx].value);
            }),
            isCurved: true,
            color: AppColors.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withAlpha(25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<_ChartDataPoint> points) {
    final total = points.fold<double>(0.0, (sum, p) => sum + (p.value > 0 ? p.value : 0));

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 44,
              sections: List.generate(points.length, (idx) {
                final p = points[idx];
                final pct = total > 0 ? (p.value / total * 100) : 0.0;
                return PieChartSectionData(
                  color: _palette[idx % _palette.length],
                  value: p.value > 0 ? p.value : 0.001,
                  title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                  radius: 54,
                  titleStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: List.generate(points.length, (idx) {
            final p = points[idx];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _palette[idx % _palette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  p.label,
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  static String _compactNumber(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)}k';
    return val.toStringAsFixed(0);
  }
}

class _ChartDataPoint {
  final String label;
  final double value;

  _ChartDataPoint({required this.label, required this.value});
}
