import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/chart_config.dart';
import '../../domain/models/query_result.dart';

class InteractiveChart extends StatefulWidget {
  final QueryResult result;
  final ChartConfig config;
  final ValueChanged<ChartConfig> onConfigChanged;

  const InteractiveChart({
    super.key,
    required this.result,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<InteractiveChart> {
  int? _touchedIndex;

  // 24 curated distinct, high-contrast colors for data visualization
  static const List<Color> _curatedPalette = [
    Color(0xFFEE5D36), // Vibrant Orange (Accent)
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFF8B5CF6), // Violet Purple
    Color(0xFFF59E0B), // Amber Gold
    Color(0xFFEC4899), // Pink Rose
    Color(0xFF06B6D4), // Cyan
    Color(0xFF84CC16), // Lime
    Color(0xFF6366F1), // Indigo
    Color(0xFFF97316), // Coral Orange
    Color(0xFF14B8A6), // Teal
    Color(0xFFA855F7), // Orchid
    Color(0xFFE11D48), // Crimson Red
    Color(0xFF0284C7), // Sky Blue
    Color(0xFFD97706), // Bronze
    Color(0xFF059669), // Forest Green
    Color(0xFF7C3AED), // Deep Violet
    Color(0xFFDB2777), // Deep Rose
    Color(0xFF0891B2), // Deep Cyan
    Color(0xFF475569), // Slate
    Color(0xFFEAB308), // Yellow
    Color(0xFF4F46E5), // Cobalt
    Color(0xFF15803D), // Dark Green
    Color(0xFFBE123C), // Ruby
  ];

  Color _getColor(int index, int total) {
    if (index < _curatedPalette.length) {
      return _curatedPalette[index];
    }
    // Dynamic equidistant hue generation on HSV/HSL circle so colors never duplicate
    final hue = (index * (360.0 / max(total, 1))) % 360;
    return HSLColor.fromAHSL(1.0, hue, 0.75, 0.52).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final labelIdx = widget.result.columns.indexOf(widget.config.labelColumn);
    final valIdx = widget.result.columns.indexOf(widget.config.valueColumn);

    if (labelIdx == -1 || valIdx == -1) {
      return Center(
        child: Text(
          'Grafik için sütun seçin.',
          style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final dataPoints = <_ChartDataPoint>[];
    for (final row in widget.result.rows) {
      if (labelIdx >= row.length || valIdx >= row.length) continue;
      final label = row[labelIdx]?.toString() ?? '—';
      final rawVal = row[valIdx];
      final val = (rawVal is num) ? rawVal.toDouble() : (double.tryParse(rawVal?.toString() ?? '') ?? 0.0);
      dataPoints.add(_ChartDataPoint(label: label, value: val));
    }

    final limitedPoints = dataPoints.take(widget.config.maxItems).toList();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (limitedPoints.isEmpty) {
      return Center(
        child: Text(
          'Sayısal veri bulunamadı.',
          style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 4, 16, isLandscape ? 16 : 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildControls(context, isLandscape),
              const SizedBox(height: 10),
              _renderChart(limitedPoints, isLandscape, constraints.maxWidth),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context, bool isLandscape) {
    if (isLandscape) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildDropdown(
                label: 'Kategori (X)',
                value: widget.config.labelColumn,
                items: widget.result.columns,
                onChanged: (val) {
                  if (val != null) {
                    widget.onConfigChanged(widget.config.copyWith(labelColumn: val));
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _buildDropdown(
                label: 'Değer (Y)',
                value: widget.config.valueColumn,
                items: widget.result.columns,
                onChanged: (val) {
                  if (val != null) {
                    widget.onConfigChanged(widget.config.copyWith(valueColumn: val));
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Grafik Türü:',
                    style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildTypeChip('Çubuk', ChartType.bar, Icons.bar_chart_rounded),
                      const SizedBox(width: 6),
                      _buildTypeChip('Çizgi', ChartType.line, Icons.show_chart_rounded),
                      const SizedBox(width: 6),
                      _buildTypeChip('Pasta', ChartType.pie, Icons.pie_chart_outline_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  value: widget.config.labelColumn,
                  items: widget.result.columns,
                  onChanged: (val) {
                    if (val != null) {
                      widget.onConfigChanged(widget.config.copyWith(labelColumn: val));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  label: 'Değer (Y)',
                  value: widget.config.valueColumn,
                  items: widget.result.columns,
                  onChanged: (val) {
                    if (val != null) {
                      widget.onConfigChanged(widget.config.copyWith(valueColumn: val));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Grafik Türü:',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    _buildTypeChip('Çubuk', ChartType.bar, Icons.bar_chart_rounded),
                    const SizedBox(width: 6),
                    _buildTypeChip('Çizgi', ChartType.line, Icons.show_chart_rounded),
                    const SizedBox(width: 6),
                    _buildTypeChip('Pasta', ChartType.pie, Icons.pie_chart_outline_rounded),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, ChartType type, IconData icon) {
    final isSelected = widget.config.type == type;
    return Expanded(
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _touchedIndex = null;
            });
            widget.onConfigChanged(widget.config.copyWith(type: type));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : AppColors.cardMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
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
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.cardMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
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

  Widget _renderChart(List<_ChartDataPoint> points, bool isLandscape, double maxWidth) {
    switch (widget.config.type) {
      case ChartType.bar:
        return _buildBarChart(points, isLandscape);
      case ChartType.line:
        return _buildLineChart(points, isLandscape);
      case ChartType.pie:
        return _buildPieChart(points, isLandscape);
    }
  }

  Widget _buildBarChart(List<_ChartDataPoint> points, bool isLandscape) {
    final maxY = points.map((p) => p.value).fold<double>(0.0, max) * 1.15;

    return Container(
      height: isLandscape ? 220 : 300,
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
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
                reservedSize: 32,
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
            getDrawingHorizontalLine: (val) => FlLine(
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
                  color: _getColor(idx, points.length),
                  width: points.length > 10 ? 12 : 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<_ChartDataPoint> points, bool isLandscape) {
    final maxY = points.map((p) => p.value).fold<double>(0.0, max) * 1.15;

    return Container(
      height: isLandscape ? 220 : 300,
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
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
            getDrawingHorizontalLine: (val) => FlLine(
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
                reservedSize: 32,
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
      ),
    );
  }

  Widget _buildPieChart(List<_ChartDataPoint> points, bool isLandscape) {
    final total = points.fold<double>(0.0, (sum, p) => sum + (p.value > 0 ? p.value : 0));

    // Active touched slice details
    final touchedPoint = (_touchedIndex != null && _touchedIndex! >= 0 && _touchedIndex! < points.length)
        ? points[_touchedIndex!]
        : null;
    final touchedPct = (touchedPoint != null && total > 0)
        ? (touchedPoint.value / total * 100)
        : null;

    final pieWidget = SizedBox(
      width: isLandscape ? 170 : double.infinity,
      height: isLandscape ? 170 : 185,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      return;
                    }
                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: isLandscape ? 30 : 35,
              sections: List.generate(points.length, (idx) {
                final isTouched = idx == _touchedIndex;
                final p = points[idx];
                final pct = total > 0 ? (p.value / total * 100) : 0.0;
                final radius = isTouched ? (isLandscape ? 38.0 : 42.0) : (isLandscape ? 30.0 : 35.0);

                return PieChartSectionData(
                  color: _getColor(idx, points.length),
                  value: p.value > 0 ? p.value : 0.001,
                  title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                  radius: radius,
                  titleStyle: GoogleFonts.spaceGrotesk(
                    fontSize: isTouched ? 11 : 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),

          // Center Information Hole
          if (touchedPoint != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  touchedPoint.label.length > 9
                      ? '${touchedPoint.label.substring(0, 8)}…'
                      : touchedPoint.label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${touchedPct!.toStringAsFixed(1)}%',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ],
            )
          else
            Text(
              '${points.length} Dilim',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );

    final legendWidget = Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: isLandscape ? WrapAlignment.start : WrapAlignment.center,
      children: List.generate(points.length, (idx) {
        final p = points[idx];
        final color = _getColor(idx, points.length);
        final isTouched = idx == _touchedIndex;

        return GestureDetector(
          onTap: () {
            setState(() {
              _touchedIndex = (_touchedIndex == idx) ? null : idx;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isTouched ? color.withAlpha(25) : AppColors.cardMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isTouched ? color : AppColors.border,
                width: isTouched ? 1.5 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  p.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: isTouched ? FontWeight.w700 : FontWeight.w500,
                    color: isTouched ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );

    if (isLandscape) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            pieWidget,
            const SizedBox(width: 14),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: legendWidget,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          pieWidget,
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 110),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: legendWidget,
            ),
          ),
        ],
      ),
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
