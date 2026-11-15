import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/data_profiler_service.dart';
import '../../domain/models/table_schema.dart';

class DataProfilerWidget extends StatefulWidget {
  final List<TableSchema> tables;
  final String? initialTable;
  final DataProfilerService profilerService;
  final void Function(String sql) onExecute;
  final ValueChanged<String>? onTableChanged;

  const DataProfilerWidget({
    super.key,
    required this.tables,
    this.initialTable,
    required this.profilerService,
    required this.onExecute,
    this.onTableChanged,
  });

  @override
  State<DataProfilerWidget> createState() => _DataProfilerWidgetState();
}

class _DataProfilerWidgetState extends State<DataProfilerWidget> {
  late String _selectedTable;
  TableProfile? _profile;
  bool _isLoading = false;

  String? _pivotRowCol;
  String? _pivotCol;
  String? _pivotValCol;
  String _pivotAgg = 'SUM';

  @override
  void initState() {
    super.initState();
    _selectedTable = widget.initialTable ?? '';
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant DataProfilerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTable != oldWidget.initialTable) {
      setState(() => _selectedTable = widget.initialTable ?? '');
      _loadProfile();
    }
  }

  TableSchema? get _currentTableSchema {
    if (_selectedTable.isEmpty) return null;
    try {
      return widget.tables.firstWhere((t) => t.name == _selectedTable);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfile() async {
    final schema = _currentTableSchema;
    if (schema == null) {
      setState(() => _profile = null);
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      final p = widget.profilerService.profileTable(schema);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _isLoading = false;
        if (schema.columns.length >= 2) {
          _pivotRowCol = schema.columns.first.name;
          _pivotCol = schema.columns[1].name;
          _pivotValCol = schema.columns.firstWhere(
            (c) => c.type == 'INTEGER' || c.type == 'REAL',
            orElse: () => schema.columns.last,
          ).name;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tables.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Center(
          child: Text(
            'Analiz edilecek tablo yok.',
            style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent),
              ),
              const SizedBox(height: 16),
              Text(
                'Tablo Analiz Ediliyor...',
                style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Sütun tipleri ve istatistikler taranıyor',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final schema = _currentTableSchema;

    if (_selectedTable.isEmpty || schema == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.analytics_rounded, size: 22, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analiz Edilecek Tabloyu Seçin',
                      style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'İstatistik ve profil için bir tablo seçin',
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.tables.map((table) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _selectedTable = table.name);
                    widget.onTableChanged?.call(table.name);
                    _loadProfile();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_rows_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          table.name,
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${table.rowCount} satır)',
                          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Text(
                  'Tablo:',
                  style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.tables.any((t) => t.name == _selectedTable) ? _selectedTable : null,
                        hint: Text('Tablo Seçiniz...', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.spaceGrotesk(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                        items: widget.tables.map((t) {
                          return DropdownMenuItem(value: t.name, child: Text(t.name));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedTable = val);
                            widget.onTableChanged?.call(val);
                            _loadProfile();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Overview Metrics - Blockit big numbers
          if (_profile != null) ...[
            Row(
              children: [
                _buildStatPill('KAYIT', '${_profile!.totalRows}', AppColors.primary),
                const SizedBox(width: 10),
                _buildStatPill('SÜTUN', '${_profile!.columnCount}', AppColors.accent),
                const SizedBox(width: 10),
                _buildStatPill(
                  'DUPLİKE',
                  '${_profile!.duplicateCount}',
                  _profile!.duplicateCount > 0 ? AppColors.error : AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Quick Action Cards
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hızlı Analiz',
                  style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionButton(
                      icon: Icons.copy_all_rounded,
                      label: 'Tekrar Edenler',
                      color: AppColors.error,
                      onTap: () {
                        widget.onExecute(widget.profilerService.generateDuplicatesSql(schema));
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.search_off_rounded,
                      label: 'Eksik Veriler',
                      color: AppColors.warning,
                      onTap: () {
                        widget.onExecute(widget.profilerService.generateMissingDataSql(schema));
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.query_stats_rounded,
                      label: 'Sayısal Özet',
                      color: AppColors.success,
                      onTap: () {
                        widget.onExecute(widget.profilerService.generateNumericSummarySql(schema));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Column Health & Types Table
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_profile != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sütun Sağlığı',
                    style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowHeight: 38,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 42,
                      headingRowColor: WidgetStateProperty.all(AppColors.cardMuted),
                      columns: [
                        DataColumn(label: Text('Sütun', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Tip', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Boş', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Eksik %', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Benzersiz', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700))),
                      ],
                      rows: _profile!.columns.map((col) {
                        return DataRow(
                          cells: [
                            DataCell(Text(col.name, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryWash,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(col.type, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            DataCell(Text('${col.nullCount}', style: GoogleFonts.dmSans(fontSize: 12, color: col.hasMissingData ? AppColors.error : AppColors.textPrimary))),
                            DataCell(
                              Text(
                                '%${col.nullPercentage.toStringAsFixed(1)}',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: col.nullPercentage > 0 ? AppColors.error : AppColors.success,
                                ),
                              ),
                            ),
                            DataCell(Text('${col.distinctCount}', style: GoogleFonts.dmSans(fontSize: 12))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Pivot Table Generator
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pivot Tablo',
                    style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniDropdown(
                          label: 'Satır',
                          value: _pivotRowCol,
                          items: schema.columnNames,
                          onChanged: (v) => setState(() => _pivotRowCol = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniDropdown(
                          label: 'Sütun',
                          value: _pivotCol,
                          items: schema.columnNames,
                          onChanged: (v) => setState(() => _pivotCol = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniDropdown(
                          label: 'Değer',
                          value: _pivotValCol,
                          items: schema.columnNames,
                          onChanged: (v) => setState(() => _pivotValCol = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniDropdown(
                          label: 'İşlem',
                          value: _pivotAgg,
                          items: const ['SUM', 'COUNT', 'AVG', 'MAX', 'MIN'],
                          onChanged: (v) => setState(() => _pivotAgg = v ?? 'SUM'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: GestureDetector(
                      onTap: (_pivotRowCol != null && _pivotCol != null && _pivotValCol != null && _pivotRowCol != _pivotCol)
                          ? () => _executePivot(schema)
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: (_pivotRowCol != null && _pivotCol != null && _pivotValCol != null && _pivotRowCol != _pivotCol)
                              ? AppColors.primary
                              : AppColors.cardMuted,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Pivot Oluştur',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: (_pivotRowCol != null && _pivotCol != null && _pivotValCol != null && _pivotRowCol != _pivotCol)
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _executePivot(TableSchema schema) {
    if (_pivotRowCol == null || _pivotCol == null || _pivotValCol == null) return;

    try {
      final distinctVals = widget.profilerService.getDistinctColumnValues(schema.name, _pivotCol!);
      if (distinctVals.isEmpty) return;

      final pivotSql = widget.profilerService.generatePivotSql(
        tableName: schema.name,
        rowColumn: _pivotRowCol!,
        pivotColumn: _pivotCol!,
        valueColumn: _pivotValCol!,
        distinctPivotValues: distinctVals,
        aggFunction: _pivotAgg,
      );

      widget.onExecute(pivotSql);
    } catch (_) {}
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
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
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
              items: items.map((col) {
                return DropdownMenuItem(value: col, child: Text(col, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
