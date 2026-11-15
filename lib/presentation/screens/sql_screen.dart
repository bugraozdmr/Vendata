import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/export_helper.dart';
import '../providers/database_provider.dart';
import '../widgets/data_grid_table.dart';
import '../widgets/data_profiler_widget.dart';
import '../widgets/interactive_chart.dart';
import '../widgets/query_shortcuts.dart';
import '../widgets/saved_queries_sheet.dart';
import '../widgets/visual_query_builder.dart';

class SqlScreen extends ConsumerStatefulWidget {
  final String? targetTable;

  const SqlScreen({super.key, this.targetTable});

  @override
  ConsumerState<SqlScreen> createState() => _SqlScreenState();
}

class _SqlScreenState extends ConsumerState<SqlScreen> {
  late final TextEditingController _sqlController;
  int _activeTab = 0;
  int _queryMode = 0;
  int _resultType = 0;
  String? _activeTable;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _activeTable = widget.targetTable;
    final initialSql = (_activeTable != null && _activeTable!.isNotEmpty)
        ? 'SELECT * FROM "$_activeTable" LIMIT 50;'
        : '';

    _sqlController = TextEditingController(text: initialSql);
    // Otomatik sorgu çalıştırma yapılmaz; kullanıcı manuel çalıştırır
  }

  @override
  void didUpdateWidget(covariant SqlScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetTable != oldWidget.targetTable) {
      setState(() {
        _activeTable = widget.targetTable;
        if (widget.targetTable != null) {
          _sqlController.text = 'SELECT * FROM "${widget.targetTable}" LIMIT 50;';
        }
      });
    }
  }

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  void _handleShortcutInsert(String snippet, bool replace) {
    if (replace) {
      _sqlController.text = snippet;
      _sqlController.selection = TextSelection.fromPosition(TextPosition(offset: snippet.length));
    } else {
      final current = _sqlController.text;
      final selection = _sqlController.selection;
      final start = selection.start >= 0 ? selection.start : current.length;
      final end = selection.end >= 0 ? selection.end : current.length;

      final newText = current.replaceRange(start, end, snippet);
      _sqlController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + snippet.length),
      );
    }
  }

  Future<void> _runQuery([String? customSql, bool switchTab = true, String? tableName]) async {
    final sql = (customSql ?? _sqlController.text).trim();
    if (sql.isEmpty) return;
    _sqlController.text = sql;

    if (switchTab) {
      setState(() => _activeTab = 1);
    }

    final target = tableName ?? _activeTable;
    await ref.read(queryProvider.notifier).runQuery(sql, target);
  }

  @override
  Widget build(BuildContext context) {
    final queryState = ref.watch(queryProvider);
    final tablesState = ref.watch(tablesProvider);
    final chartConfig = ref.watch(chartConfigProvider);
    final hasResults = !queryState.result.hasError && queryState.result.rows.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF15161A),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: AppColors.border, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'SQL',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      SavedQueriesSheet.show(
                        context: context,
                        activeTable: _activeTable,
                        onSelectQuery: (sql, tableName) {
                          Navigator.pop(context);
                          if (tableName != null && tableName.isNotEmpty) {
                            setState(() => _activeTable = tableName);
                          }
                          _runQuery(sql, true, tableName);
                        },
                        onLoadIntoEditor: (sql, tableName) {
                          Navigator.pop(context);
                          if (tableName != null && tableName.isNotEmpty) {
                            setState(() => _activeTable = tableName);
                          }
                          setState(() {
                            _sqlController.text = sql;
                            _activeTab = 0;
                            _queryMode = 2; // SQL Konsolu
                          });
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 18, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            'Sorgularım',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildTableSelectorBar(tablesState),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildTabButton('Sorgu', 0, Icons.edit_note_rounded),
                    _buildTabButton(
                      hasResults ? 'Sonuç (${queryState.result.rowCount})' : 'Sonuç',
                      1,
                      Icons.table_rows_rounded,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _activeTab == 0
                  ? _buildQueryInputSection(tablesState, queryState)
                  : _buildFullResultsView(queryState.result, chartConfig, queryState.isExecuting),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSelectorBar(TablesState tablesState) {
    if (tablesState.tables.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_activeTable == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.table_chart_rounded, size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            Text(
              'Tablo Seçin:',
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: tablesState.tables.map((t) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _activeTable = t.name;
                          _sqlController.text = 'SELECT * FROM "${t.name}" LIMIT 50;';
                        });
                        ref.read(queryProvider.notifier).setActiveTable(t.name);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cardMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          t.name,
                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tableInfo = tablesState.tables.where((t) => t.name == _activeTable).firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.table_chart_rounded, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _activeTable!,
                    style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tableInfo != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${tableInfo.rowCount} satır)',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tabloyu Değiştir',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            onSelected: (val) {
              if (val == '__clear__') {
                setState(() {
                  _activeTable = null;
                  _sqlController.text = '';
                });
                ref.read(queryProvider.notifier).setActiveTable(null);
              } else {
                setState(() {
                  _activeTable = val;
                  _sqlController.text = 'SELECT * FROM "$val" LIMIT 50;';
                });
                ref.read(queryProvider.notifier).setActiveTable(val);
              }
            },
            itemBuilder: (ctx) => [
              ...tablesState.tables.map((t) => PopupMenuItem(
                    value: t.name,
                    child: Text(t.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                  )),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: '__clear__',
                child: Text('Tablo Seçimini Kaldır', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error)),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Değiştir',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueryInputSection(TablesState tablesState, QueryState queryState) {
    final profilerService = ref.watch(dataProfilerServiceProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildModePill('Sihirbaz', 0, Icons.auto_fix_high_rounded),
                const SizedBox(width: 8),
                _buildModePill('Analiz', 1, Icons.analytics_rounded),
                const SizedBox(width: 8),
                _buildModePill('SQL Konsol', 2, Icons.code_rounded),
              ],
            ),
          ),
        ),
        if (queryState.result.hasError) _buildErrorBanner(queryState.result.error!),
        Expanded(
          child: _queryMode == 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: VisualQueryBuilder(
                    tables: tablesState.tables,
                    initialTable: _activeTable,
                    isExecuting: queryState.isExecuting,
                    onExecute: (sql) => _runQuery(sql, true, _activeTable),
                    onTableChanged: (tableName) => setState(() => _activeTable = tableName),
                  ),
                )
              : (_queryMode == 1
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: DataProfilerWidget(
                        tables: tablesState.tables,
                        initialTable: _activeTable,
                        profilerService: profilerService,
                        onExecute: (sql) => _runQuery(sql, true, _activeTable),
                        onTableChanged: (tableName) => setState(() => _activeTable = tableName),
                      ),
                    )
                  : _buildManualEditor(tablesState, queryState)),
        ),
      ],
    );
  }

  Widget _buildModePill(String title, int mode, IconData icon) {
    final isSelected = _queryMode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _queryMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withAlpha(30), blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEditor(TablesState tablesState, QueryState queryState) {
    final availableTableNames = tablesState.tables.map((t) => t.name).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      child: Column(
        children: [
          QueryShortcuts(
            availableTables: availableTableNames,
            onInsert: _handleShortcutInsert,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TextField(
                  controller: _sqlController,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  style: GoogleFonts.firaCode(
                    fontSize: 13,
                    color: AppColors.codeText,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'SQL sorgunuzu yazın...',
                    hintStyle: GoogleFonts.firaCode(fontSize: 13, color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (context) {
              final currentSql = _sqlController.text.trim();
              final isFavorite = queryState.savedQueries.any((q) => q.queryText.trim() == currentSql && q.isFavorite);

              return Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: currentSql.isEmpty
                        ? null
                        : () {
                            ref.read(queryProvider.notifier).toggleFavoriteBySql(currentSql);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isFavorite ? 'Yıldız kaldırıldı' : 'Sorgu yıldızlara eklendi',
                                  style: GoogleFonts.dmSans(),
                                ),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            setState(() {});
                          },
                    child: Container(
                      height: 52,
                      width: 52,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isFavorite ? AppColors.warning : AppColors.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isFavorite ? AppColors.warning : AppColors.textMuted,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: GestureDetector(
                        onTap: queryState.isExecuting ? null : () => _runQuery(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: queryState.isExecuting ? AppColors.textMuted : AppColors.accent,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: queryState.isExecuting
                                ? null
                                : [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: queryState.isExecuting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Çalıştır',
                                        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFullResultsView(dynamic result, dynamic chartConfig, bool isExecuting) {
    if (isExecuting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sorgu Çalıştırılıyor...',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sonuçlar hazırlanıyor',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (result.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.errorWash,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.error_outline_rounded, size: 32, color: AppColors.error),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sorgu Hatası',
                  style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  result.error!,
                  style: GoogleFonts.firaCode(fontSize: 12, color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _activeTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('Sorguyu Düzenle', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (result.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.query_stats_rounded, size: 52, color: AppColors.textMuted.withAlpha(100)),
              const SizedBox(height: 16),
              Text(
                'Sonuç Yok',
                style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Sorgu çalıştırarak sonuçları görüntüleyin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _activeTab = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Sorgu Yaz', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${result.rowCount} satır  •  ${result.executionTimeMs} ms',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              _buildMiniToggle('Tablo', Icons.table_rows_rounded, _resultType == 0, () => setState(() => _resultType = 0)),
              const SizedBox(width: 6),
              _buildMiniToggle('Grafik', Icons.bar_chart_rounded, _resultType == 1, () => setState(() => _resultType = 1)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isExporting
                    ? null
                    : () async {
                        setState(() => _isExporting = true);
                        try {
                          await ExportHelper.shareAsExcel(result);
                        } finally {
                          if (mounted) setState(() => _isExporting = false);
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successWash,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.success,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 16, color: AppColors.success),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: _resultType == 0
                ? DataGridTable(result: result)
                : (chartConfig == null
                    ? Center(
                        child: Text(
                          'Grafik için sayısal sütun gerekli.',
                          style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 14),
                        ),
                      )
                    : InteractiveChart(
                        result: result,
                        config: chartConfig,
                        onConfigChanged: (newConfig) {
                          ref.read(chartConfigProvider.notifier).updateConfig(newConfig);
                        },
                      )),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniToggle(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.firaCode(fontSize: 11, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
