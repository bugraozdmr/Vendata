import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/export_helper.dart';
import '../../data/services/db_session.dart';
import '../../domain/models/chart_config.dart';
import '../../domain/models/query_result.dart';
import '../../domain/models/visual_query.dart';
import '../providers/connection_provider.dart';
import '../providers/database_provider.dart';
import '../widgets/data_grid_table.dart';
import '../widgets/data_profiler_widget.dart';
import '../widgets/interactive_chart.dart';
import '../widgets/query_shortcuts.dart';
import '../widgets/saved_queries_sheet.dart';
import '../widgets/visual_query_builder.dart';
import 'fullscreen_table_screen.dart';

class QueryTabModel {
  final String id;
  String title;
  final TextEditingController sqlController;
  String? activeTable;
  int queryMode; // 0: Sihirbaz, 1: Analiz, 2: SQL Konsol
  int activeTab; // 0: Sorgu, 1: Sonuç
  int resultType; // 0: Tablo, 1: Grafik
  QueryResult? result;
  ChartConfig? chartConfig;
  bool isExecuting;
  VisualQuery? visualQuery;

  QueryTabModel({
    required this.id,
    required this.title,
    required this.sqlController,
    this.activeTable,
    this.queryMode = 0,
    this.activeTab = 0,
    this.resultType = 0,
    this.result,
    this.chartConfig,
    this.isExecuting = false,
    this.visualQuery,
  });

  void dispose() {
    sqlController.dispose();
  }
}

class SqlScreen extends ConsumerStatefulWidget {
  final String? targetTable;

  const SqlScreen({super.key, this.targetTable});

  @override
  ConsumerState<SqlScreen> createState() => _SqlScreenState();
}

class _SqlScreenState extends ConsumerState<SqlScreen> {
  final List<QueryTabModel> _tabs = [];
  int _selectedTabIndex = 0;
  int _tabCounter = 1;
  bool _isExporting = false;

  QueryTabModel get _currentTab => _tabs[_selectedTabIndex];

  @override
  void initState() {
    super.initState();
    final initialTable = widget.targetTable;
    final quotedInitial = initialTable != null && initialTable.isNotEmpty
        ? ref.read(sessionProvider).quoteIdentifier(initialTable)
        : '';
    final initialSql = (initialTable != null && initialTable.isNotEmpty)
        ? 'SELECT * FROM $quotedInitial LIMIT 50;'
        : '';
    final initialTitle = (initialTable != null && initialTable.isNotEmpty)
        ? initialTable
        : 'Sorgu 1';

    _tabs.add(QueryTabModel(
      id: 'tab_init_${DateTime.now().millisecondsSinceEpoch}',
      title: initialTitle,
      sqlController: TextEditingController(text: initialSql),
      activeTable: initialTable,
      queryMode: (initialTable != null && initialTable.isNotEmpty) ? 0 : 2,
      activeTab: 0,
    ));
    _selectedTabIndex = 0;
    _tabCounter = 2;
  }

  @override
  void didUpdateWidget(covariant SqlScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetTable != oldWidget.targetTable && widget.targetTable != null) {
      final existingIdx = _tabs.indexWhere((t) => t.activeTable == widget.targetTable);
      if (existingIdx != -1) {
        setState(() {
          _selectedTabIndex = existingIdx;
        });
      } else {
        _addNewTab(tableName: widget.targetTable);
      }
    }
  }

  @override
  void dispose() {
    for (final tab in _tabs) {
      tab.dispose();
    }
    super.dispose();
  }

  void _addNewTab({String? tableName, String? initialSql}) {
    final count = _tabCounter++;
    final sql = (tableName != null && tableName.isNotEmpty)
        ? 'SELECT * FROM ${ref.read(sessionProvider).quoteIdentifier(tableName)} LIMIT 50;'
        : (initialSql ?? '');
    final title = (tableName != null && tableName.isNotEmpty)
        ? tableName
        : 'Sorgu $count';

    final newTab = QueryTabModel(
      id: 'tab_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      sqlController: TextEditingController(text: sql),
      activeTable: tableName,
      queryMode: (initialSql != null && initialSql.isNotEmpty) ? 2 : (tableName != null ? 0 : 2),
      activeTab: 0,
    );

    setState(() {
      _tabs.add(newTab);
      _selectedTabIndex = _tabs.length - 1;
    });
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) {
      final onlyTab = _tabs[0];
      setState(() {
        onlyTab.title = 'Sorgu 1';
        onlyTab.sqlController.text = '';
        onlyTab.activeTable = null;
        onlyTab.queryMode = 0;
        onlyTab.activeTab = 0;
        onlyTab.result = null;
        onlyTab.chartConfig = null;
        onlyTab.isExecuting = false;
      });
      return;
    }

    setState(() {
      final removed = _tabs.removeAt(index);
      removed.dispose();
      if (_selectedTabIndex >= _tabs.length) {
        _selectedTabIndex = _tabs.length - 1;
      }
    });
  }

  void _handleShortcutInsert(String snippet, bool replace) {
    final controller = _currentTab.sqlController;
    if (replace) {
      controller.text = snippet;
      controller.selection = TextSelection.fromPosition(TextPosition(offset: snippet.length));
    } else {
      final current = controller.text;
      final selection = controller.selection;
      final start = selection.start >= 0 ? selection.start : current.length;
      final end = selection.end >= 0 ? selection.end : current.length;

      final newText = current.replaceRange(start, end, snippet);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + snippet.length),
      );
    }
  }

  ChartConfig? _autoDetectChartConfig(QueryResult result) {
    if (result.columns.isEmpty || result.rows.isEmpty) {
      return null;
    }

    String? candidateLabel;
    String? candidateValue;

    for (var colIdx = 0; colIdx < result.columns.length; colIdx++) {
      final colName = result.columns[colIdx];
      final firstVal = result.rows.first[colIdx];

      if (firstVal is num && candidateValue == null) {
        candidateValue = colName;
      } else if (firstVal is String && candidateLabel == null) {
        candidateLabel = colName;
      }
    }

    candidateLabel ??= result.columns.first;
    candidateValue ??= result.columns.length > 1 ? result.columns[1] : result.columns.first;

    return ChartConfig(
      type: ChartType.bar,
      labelColumn: candidateLabel,
      valueColumn: candidateValue,
    );
  }

  Future<void> _runCurrentTabQuery([String? customSql, bool switchTab = true, String? tableName]) async {
    final tab = _currentTab;
    final sql = (customSql ?? tab.sqlController.text).trim();
    if (sql.isEmpty) return;
    tab.sqlController.text = sql;

    setState(() {
      tab.isExecuting = true;
      if (switchTab) {
        tab.activeTab = 1;
      }
    });

    // Micro-delay to yield to Flutter scheduler for smooth spinner rendering
    await Future.delayed(const Duration(milliseconds: 250));

    final target = tableName ?? tab.activeTable;
    final session = ref.read(sessionProvider);
    final queryResult = await session.execute(sql, tableName: target);

    ChartConfig? autoChart;
    if (!queryResult.hasError && queryResult.rows.isNotEmpty) {
      autoChart = _autoDetectChartConfig(queryResult);
    }

    // Refresh history & saved queries in sqlite
    ref.read(queryProvider.notifier).refreshSavedQueries(tableName: target);

    if (mounted) {
      setState(() {
        tab.isExecuting = false;
        tab.result = queryResult;
        if (autoChart != null) {
          tab.chartConfig = autoChart;
        }
        if (target != null && tab.title.startsWith('Sorgu ')) {
          tab.title = target;
        }
      });
    }
  }

  Future<void> _copyToClipboard(String text, String message) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showQueryPlan(QueryTabModel tab) async {
    final sql = tab.sqlController.text.trim();
    if (sql.isEmpty) return;

    final session = ref.read(sessionProvider);
    final explainSql = session.dialect == DbDialect.sqlite
        ? 'EXPLAIN QUERY PLAN $sql'
        : 'EXPLAIN $sql';
    final result = await session.execute(
      explainSql,
      tableName: tab.activeTable,
      logQuery: false,
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Sorgu Planı',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: SizedBox(
          width: 720,
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: result.hasError
              ? Text(
                  result.error ?? 'Sorgu planı alınamadı.',
                  style: GoogleFonts.firaCode(fontSize: 12, color: AppColors.error),
                )
              : DataGridTable(result: result),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Kapat',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _resultAsCsv(QueryResult result) {
    final rows = <List<dynamic>>[result.columns, ...result.rows];
    return Csv().encode(rows);
  }

  List<String> _joinTypesFor(DbDialect dialect) {
    switch (dialect) {
      case DbDialect.mysql:
        return const ['INNER JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'CROSS JOIN'];
      case DbDialect.postgresql:
        return const ['INNER JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'FULL OUTER JOIN', 'CROSS JOIN'];
      case DbDialect.sqlite:
        return const ['INNER JOIN', 'LEFT JOIN', 'CROSS JOIN', 'RIGHT JOIN', 'FULL OUTER JOIN'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablesState = ref.watch(tablesProvider);
    final currentTab = _currentTab;
    final hasResults = currentTab.result != null && !currentTab.result!.hasError && currentTab.result!.rows.isNotEmpty;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLandscape) ...[
              // Landscape Compact Single Bar: Tab Bar + Sub Tabs + Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Row(
                  children: [
                    Expanded(child: _buildTabBar(margin: EdgeInsets.zero)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.cardMuted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabButton('Sorgu', 0, Icons.edit_note_rounded, expand: false),
                          _buildTabButton(
                            hasResults ? 'Sonuç (${currentTab.result!.rowCount})' : 'Sonuç',
                            1,
                            Icons.table_rows_rounded,
                            expand: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSavedQueriesButton(currentTab),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTableSelectorBar(tablesState),
              ),
              const SizedBox(height: 4),
            ] else ...[
              // Portrait Spacious Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SQL',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -1.0,
                          ),
                        ),
                        if (tablesState.isRemote) ...[
                          const SizedBox(width: 10),
                          _buildRemoteIndicator(tablesState),
                        ],
                      ],
                    ),
                    _buildSavedQueriesButton(currentTab),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildTabBar(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTableSelectorBar(tablesState),
              ),
              const SizedBox(height: 8),
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
                        hasResults ? 'Sonuç (${currentTab.result!.rowCount})' : 'Sonuç',
                        1,
                        Icons.table_rows_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Content Area: Either Query Input or Results
            Expanded(
              child: currentTab.activeTab == 0
                  ? _buildQueryInputSection(tablesState)
                  : _buildFullResultsView(currentTab.result, currentTab.chartConfig, currentTab.isExecuting),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteIndicator(TablesState tablesState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.successWash,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_rounded, size: 12, color: AppColors.success),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              tablesState.connectionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedQueriesButton(QueryTabModel currentTab) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        SavedQueriesSheet.show(
          context: context,
          activeTable: currentTab.activeTable,
          onSelectQuery: (sql, tableName) {
            Navigator.pop(context);
            if (tableName != null && tableName.isNotEmpty) {
              setState(() {
                currentTab.activeTable = tableName;
                currentTab.title = tableName;
              });
            }
            _runCurrentTabQuery(sql, true, tableName);
          },
          onLoadIntoEditor: (sql, tableName) {
            Navigator.pop(context);
            setState(() {
              if (tableName != null && tableName.isNotEmpty) {
                currentTab.activeTable = tableName;
                currentTab.title = tableName;
              }
              currentTab.sqlController.text = sql;
              currentTab.activeTab = 0;
              currentTab.queryMode = 2; // SQL Konsolu
            });
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 18, color: AppColors.warning),
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
    );
  }

  Widget _buildTabBar({EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 20)}) {
    return Container(
      height: 38,
      margin: margin,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _tabs.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = index == _selectedTabIndex;
                return _buildTabPill(tab, index, isSelected);
              },
            ),
          ),
          const SizedBox(width: 8),
          _buildNewTabButton(),
        ],
      ),
    );
  }

  Widget _buildTabPill(QueryTabModel tab, int index, bool isSelected) {
    final hasError = tab.result != null && tab.result!.hasError;
    final hasRows = tab.result != null && !tab.result!.hasError && tab.result!.rows.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedTabIndex != index) {
          setState(() {
            _selectedTabIndex = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? Colors.black.withAlpha(20) : Colors.black.withAlpha(4),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasError)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              )
            else if (hasRows)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              )
            else
              Icon(
                Icons.terminal_rounded,
                size: 13,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
              ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                tab.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _closeTab(index),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: isSelected ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewTabButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _addNewTab(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Icon(Icons.add_rounded, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildTableSelectorBar(TablesState tablesState) {
    if (tablesState.tables.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentTab = _currentTab;

    if (currentTab.activeTable == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
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
              child: Icon(Icons.table_chart_rounded, size: 16, color: AppColors.accent),
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
                          currentTab.activeTable = t.name;
                          currentTab.sqlController.text =
                              'SELECT * FROM ${ref.read(sessionProvider).quoteIdentifier(t.name)} LIMIT 50;';
                          if (currentTab.title.startsWith('Sorgu ')) {
                            currentTab.title = t.name;
                          }
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

    final tableInfo = tablesState.tables.where((t) => t.name == currentTab.activeTable).firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
            child: Icon(Icons.table_chart_rounded, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    currentTab.activeTable!,
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
            color: AppColors.surface,
            onSelected: (val) {
              if (val == '__clear__') {
                setState(() {
                  currentTab.activeTable = null;
                  currentTab.sqlController.text = '';
                  currentTab.title = 'Sorgu ${_selectedTabIndex + 1}';
                });
                ref.read(queryProvider.notifier).setActiveTable(null);
              } else {
                setState(() {
                  currentTab.activeTable = val;
                  currentTab.sqlController.text =
                      'SELECT * FROM ${ref.read(sessionProvider).quoteIdentifier(val)} LIMIT 50;';
                  currentTab.title = val;
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
                  Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon, {bool expand = true}) {
    final isSelected = _currentTab.activeTab == index;
    final btn = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentTab.activeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.textPrimary : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );

    return expand ? Expanded(child: btn) : btn;
  }

  Widget _buildQueryInputSection(TablesState tablesState) {
    final profilerService = ref.watch(dataProfilerServiceProvider);
    final queryState = ref.watch(queryProvider);
    final currentTab = _currentTab;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final horizontalPad = isLandscape ? 12.0 : 20.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 6, horizontalPad, 6),
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
        if (currentTab.result?.hasError == true) _buildErrorBanner(currentTab.result!.error!),
        Expanded(
          child: currentTab.queryMode == 0
              ? Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPad, 4, horizontalPad, 0),
                  child: VisualQueryBuilder(
                    key: ValueKey('vqb_${currentTab.id}'),
                    tables: tablesState.tables,
                    initialTable: currentTab.activeTable,
                    initialQuery: currentTab.visualQuery ??
                        VisualQuery.tryParseSql(currentTab.sqlController.text),
                    joinTypes: _joinTypesFor(ref.read(sessionProvider).dialect),
                    isExecuting: currentTab.isExecuting,
                    onQueryChanged: (vq) {
                      currentTab.visualQuery = vq;
                      currentTab.sqlController.text = vq.toSql();
                    },
                    onExecute: (sql) {
                      currentTab.visualQuery ??= VisualQuery.tryParseSql(sql);
                      _runCurrentTabQuery(sql, true, currentTab.activeTable);
                    },
                    onTableChanged: (tableName) => setState(() {
                      currentTab.activeTable = tableName;
                      if (currentTab.visualQuery != null) {
                        currentTab.visualQuery!.selectedTable = tableName;
                      }
                      if (currentTab.title.startsWith('Sorgu ')) {
                        currentTab.title = tableName;
                      }
                    }),
                  ),
                )
              : (currentTab.queryMode == 1
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 4, horizontalPad, 0),
                      child: DataProfilerWidget(
                        key: ValueKey('dpw_${currentTab.id}'),
                        tables: tablesState.tables,
                        initialTable: currentTab.activeTable,
                        profilerService: profilerService,
                        onExecute: (sql) => _runCurrentTabQuery(sql, true, currentTab.activeTable),
                        onTableChanged: (tableName) => setState(() {
                          currentTab.activeTable = tableName;
                          if (currentTab.title.startsWith('Sorgu ')) {
                            currentTab.title = tableName;
                          }
                        }),
                      ),
                    )
                  : _buildManualEditor(tablesState, currentTab, queryState)),
        ),
      ],
    );
  }

  Widget _buildModePill(String title, int mode, IconData icon) {
    final isSelected = _currentTab.queryMode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_currentTab.queryMode != mode) {
          setState(() {
            if (mode == 0 && _currentTab.sqlController.text.isNotEmpty) {
              final parsed = VisualQuery.tryParseSql(_currentTab.sqlController.text);
              if (parsed != null) {
                _currentTab.visualQuery = parsed;
                if (parsed.selectedTable.isNotEmpty) {
                  _currentTab.activeTable = parsed.selectedTable;
                }
              }
            } else if (mode == 2 && _currentTab.visualQuery != null) {
              _currentTab.sqlController.text = _currentTab.visualQuery!.toSql();
            }
            _currentTab.queryMode = mode;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
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

  Widget _buildManualEditor(TablesState tablesState, QueryTabModel tab, QueryState queryState) {
    final availableTableNames = tablesState.tables.map((t) => t.name).toList();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 4, 20, isLandscape ? 16 : 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QueryShortcuts(
            availableTables: availableTableNames,
            onInsert: _handleShortcutInsert,
          ),
          const SizedBox(height: 10),
          Container(
            height: isLandscape ? 150 : 250,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
                    if (!tab.isExecuting) _runCurrentTabQuery();
                  },
                  const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
                    if (!tab.isExecuting) _runCurrentTabQuery();
                  },
                },
                child: TextField(
                  controller: tab.sqlController,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  style: GoogleFonts.firaCode(
                    fontSize: 13,
                    color: AppColors.codeText,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'SQL sorgunuzu yazın... (Ctrl/⌘ + Enter ile çalıştırın)',
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
              final currentSql = tab.sqlController.text.trim();
              final isFavorite = queryState.favoriteQueries.contains(currentSql);

              return Row(
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Sorgu araçları',
                    color: AppColors.surface,
                    onSelected: (value) {
                      switch (value) {
                        case 'explain':
                          _showQueryPlan(tab);
                        case 'copy':
                          _copyToClipboard(tab.sqlController.text.trim(), 'SQL panoya kopyalandı');
                        case 'clear':
                          setState(() => tab.sqlController.clear());
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'explain',
                        child: Row(
                          children: [
                            Icon(Icons.account_tree_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Sorgu planını göster'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.content_copy_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('SQL\'i panoya kopyala'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Editörü temizle'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      height: 52,
                      width: 52,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Center(
                        child: Icon(Icons.more_horiz_rounded, color: AppColors.textMuted, size: 26),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: currentSql.isEmpty
                        ? null
                        : () {
                            final added = ref.read(queryProvider.notifier).toggleFavoriteBySql(
                                  currentSql,
                                  tableName: tab.activeTable,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added ? 'Sorgu yıldızlara eklendi' : 'Yıldız kaldırıldı',
                                  style: GoogleFonts.dmSans(),
                                ),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                    child: Container(
                      height: 52,
                      width: 52,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
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
                        onTap: tab.isExecuting ? null : () => _runCurrentTabQuery(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: tab.isExecuting ? AppColors.textMuted : AppColors.accent,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: tab.isExecuting
                                ? null
                                : [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: tab.isExecuting
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

  Widget _buildFullResultsView(QueryResult? result, ChartConfig? chartConfig, bool isExecuting) {
    final currentTab = _currentTab;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isExecuting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
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

    if (result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.terminal_rounded, size: 52, color: AppColors.textMuted.withAlpha(100)),
              const SizedBox(height: 16),
              Text(
                'Henüz Sorgu Çalıştırılmadı',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu sekmede henüz bir sorgu yürütülmedi. "Sorgu" sekmesine geçerek sorgunuzu oluşturup çalıştırın.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => currentTab.activeTab = 0),
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

    if (result.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
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
                  child: Icon(Icons.error_outline_rounded, size: 32, color: AppColors.error),
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
                  onTap: () => setState(() => currentTab.activeTab = 0),
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
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Sorgu başarıyla çalıştırıldı ancak dönen satır bulunamadı.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => currentTab.activeTab = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Sorguyu Değiştir', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isLandscape
                      ? '${result.rowCount} satır  •  ${result.executionTimeMs} ms'
                      : '${result.rowCount} satır',
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMiniToggle('Tablo', Icons.table_rows_rounded, currentTab.resultType == 0, () => setState(() => currentTab.resultType = 0)),
                    _buildMiniToggle('Grafik', Icons.bar_chart_rounded, currentTab.resultType == 1, () => setState(() => currentTab.resultType = 1)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => FullscreenTableScreen(
                        result: result,
                        tableName: currentTab.activeTable,
                      ),
                    ),
                  );
                },
                child: Tooltip(
                  message: 'Tam Ekran Büyüt',
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(Icons.open_in_full_rounded, size: 15, color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Dışa Aktar',
                color: AppColors.surface,
                enabled: !_isExporting,
                onSelected: (value) async {
                  if (value == 'clipboard') {
                    await _copyToClipboard(
                      _resultAsCsv(result),
                      'Sonuçlar panoya kopyalandı (CSV)',
                    );
                    return;
                  }
                  setState(() => _isExporting = true);
                  try {
                    if (value == 'excel') {
                      await ExportHelper.shareAsExcel(result);
                    } else {
                      await ExportHelper.shareAsCsv(result);
                    }
                  } finally {
                    if (mounted) setState(() => _isExporting = false);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'excel',
                    child: Row(
                      children: [
                        Icon(Icons.grid_on_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Excel (.xlsx)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(Icons.description_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('CSV (.csv)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clipboard',
                    child: Row(
                      children: [
                        Icon(Icons.content_copy_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Panoya kopyala'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.successWash,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: _isExporting
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.success,
                          ),
                        )
                      : Icon(Icons.ios_share_rounded, size: 15, color: AppColors.success),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
          child: currentTab.resultType == 0
              ? DataGridTable(result: result)
              : (currentTab.chartConfig == null
                  ? Center(
                      child: Text(
                        'Grafik için sayısal sütun gerekli.',
                        style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 14),
                      ),
                    )
                  : InteractiveChart(
                      result: result,
                      config: currentTab.chartConfig!,
                      onConfigChanged: (newConfig) {
                        setState(() {
                          currentTab.chartConfig = newConfig;
                        });
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildMiniToggle(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isActive ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
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
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
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
