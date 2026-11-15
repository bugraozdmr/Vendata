import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/file_helper.dart';
import '../../data/datasources/csv_parser.dart';
import '../../data/datasources/excel_parser.dart';
import '../../data/services/data_profiler_service.dart';
import '../../data/services/database_engine.dart';
import '../../domain/models/chart_config.dart';
import '../../domain/models/query_result.dart';
import '../../domain/models/recent_file.dart';
import '../../domain/models/saved_query.dart';
import '../../domain/models/table_schema.dart';

final databaseEngineProvider = Provider<DatabaseEngine>((ref) {
  final engine = DatabaseEngine();
  ref.onDispose(() => engine.close());
  return engine;
});

final dataProfilerServiceProvider = Provider<DataProfilerService>((ref) {
  final engine = ref.watch(databaseEngineProvider);
  return DataProfilerService(engine);
});

class TablesState {
  final List<TableSchema> tables;
  final List<RecentFile> recentFiles;
  final bool isLoading;
  final String? errorMessage;
  final String? lastImportedFileName;

  const TablesState({
    this.tables = const [],
    this.recentFiles = const [],
    this.isLoading = false,
    this.errorMessage,
    this.lastImportedFileName,
  });

  TablesState copyWith({
    List<TableSchema>? tables,
    List<RecentFile>? recentFiles,
    bool? isLoading,
    String? errorMessage,
    String? lastImportedFileName,
  }) {
    return TablesState(
      tables: tables ?? this.tables,
      recentFiles: recentFiles ?? this.recentFiles,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastImportedFileName: lastImportedFileName ?? this.lastImportedFileName,
    );
  }
}

class TablesNotifier extends StateNotifier<TablesState> {
  final DatabaseEngine _engine;

  TablesNotifier(this._engine) : super(const TablesState()) {
    refreshTables();
  }

  void refreshTables() {
    try {
      final tables = _engine.getTables();
      final recentFiles = _engine.getRecentFiles();
      state = state.copyWith(
        tables: tables,
        recentFiles: recentFiles,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> importFromFile({
    required String filePath,
    required String fileName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final type = FileHelper.getFileType(filePath);

      final baseName = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      var totalRows = 0;
      var tablesCount = 0;

      if (type == SupportedFileType.excel) {
        final datasets = ExcelParser.parse(bytes: bytes, fileBaseName: baseName);
        tablesCount = datasets.length;
        for (final dataset in datasets) {
          totalRows += dataset.rows.length;
          _engine.importDataset(dataset, sourceFileName: fileName);
        }
      } else if (type == SupportedFileType.csv) {
        final dataset = CsvParser.parse(bytes: bytes, defaultName: baseName);
        tablesCount = 1;
        totalRows = dataset.rows.length;
        _engine.importDataset(dataset, sourceFileName: fileName);
      } else if (type == SupportedFileType.sql) {
        final script = utf8.decode(bytes);
        _engine.executeRawScript(script);
        tablesCount = 1;
      } else {
        throw Exception('Desteklenmeyen dosya formatı: $fileName');
      }

      _engine.addOrUpdateRecentFile(
        RecentFile(
          fileName: fileName,
          filePath: filePath,
          fileType: type.name.toUpperCase(),
          fileSize: bytes.length,
          importedAt: DateTime.now(),
          tablesCount: tablesCount,
          totalRows: totalRows,
        ),
      );

      refreshTables();
      state = state.copyWith(lastImportedFileName: fileName);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> reimportRecentFile(RecentFile recent) async {
    final file = File(recent.filePath);
    if (!await file.exists()) {
      state = state.copyWith(
        errorMessage: 'Dosya cihazda bulunamadı: ${recent.fileName}',
      );
      return;
    }
    await importFromFile(filePath: recent.filePath, fileName: recent.fileName);
  }

  void markTableAccessed(String tableName) {
    _engine.markTableAccessed(tableName);
    refreshTables();
  }

  void deleteRecentFile(int id) {
    _engine.deleteRecentFile(id);
    refreshTables();
  }

  Future<void> dropTable(String tableName) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 150));
    _engine.dropTable(tableName);
    refreshTables();
    state = state.copyWith(isLoading: false);
  }

  Future<void> clearAll() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 150));
    _engine.clearAll();
    refreshTables();
    state = state.copyWith(isLoading: false);
  }
}

final tablesProvider = StateNotifierProvider<TablesNotifier, TablesState>((ref) {
  final engine = ref.watch(databaseEngineProvider);
  return TablesNotifier(engine);
});

class QueryState {
  final String sql;
  final QueryResult result;
  final bool isExecuting;
  final List<String> history;
  final List<SavedQuery> savedQueries;
  final String? activeTable;

  const QueryState({
    this.sql = '',
    required this.result,
    this.isExecuting = false,
    this.history = const [],
    this.savedQueries = const [],
    this.activeTable,
  });

  QueryState copyWith({
    String? sql,
    QueryResult? result,
    bool? isExecuting,
    List<String>? history,
    List<SavedQuery>? savedQueries,
    String? activeTable,
    bool clearActiveTable = false,
  }) {
    return QueryState(
      sql: sql ?? this.sql,
      result: result ?? this.result,
      isExecuting: isExecuting ?? this.isExecuting,
      history: history ?? this.history,
      savedQueries: savedQueries ?? this.savedQueries,
      activeTable: clearActiveTable ? null : (activeTable ?? this.activeTable),
    );
  }
}

class QueryNotifier extends StateNotifier<QueryState> {
  final DatabaseEngine _engine;
  final Ref _ref;

  QueryNotifier(this._engine, this._ref)
      : super(
          QueryState(
            result: QueryResult.empty(),
            history: _engine.getQueryHistory(),
            savedQueries: _engine.getSavedQueries(),
          ),
        );

  void setActiveTable(String? tableName) {
    state = state.copyWith(
      activeTable: tableName,
      clearActiveTable: tableName == null,
      savedQueries: _engine.getSavedQueries(tableName: tableName),
    );
  }

  void refreshSavedQueries({String? tableName}) {
    final tName = tableName ?? state.activeTable;
    final queries = _engine.getSavedQueries(tableName: tName);
    state = state.copyWith(
      savedQueries: queries,
      history: _engine.getQueryHistory(tableName: tName),
    );
  }

  void toggleFavorite(int id) {
    _engine.toggleQueryFavorite(id);
    refreshSavedQueries();
  }

  void toggleFavoriteBySql(String sql) {
    _engine.toggleQueryFavoriteBySql(sql);
    refreshSavedQueries();
  }

  void deleteQuery(int id) {
    _engine.deleteSavedQuery(id);
    refreshSavedQueries();
  }

  void setSql(String sql) {
    state = state.copyWith(sql: sql);
  }

  Future<void> runQuery([String? customSql, String? tableName]) async {
    final queryToRun = (customSql ?? state.sql).trim();
    if (queryToRun.isEmpty) return;

    final targetTable = tableName ?? state.activeTable;
    state = state.copyWith(isExecuting: true, sql: queryToRun);

    // Yield to the event loop so the UI frame with the spinner renders immediately!
    await Future.delayed(const Duration(milliseconds: 300));

    final result = _engine.executeQuery(queryToRun, tableName: targetTable);

    final updatedQueries = _engine.getSavedQueries(tableName: targetTable);
    final updatedHistory = _engine.getQueryHistory(tableName: targetTable);

    state = state.copyWith(
      result: result,
      isExecuting: false,
      savedQueries: updatedQueries,
      history: updatedHistory,
    );

    if (!result.hasError && result.rows.isNotEmpty) {
      _ref.read(chartConfigProvider.notifier).autoConfigure(result);
    }
  }

  void clearHistory({String? tableName, bool keepFavorites = true}) {
    _engine.clearQueryHistory(tableName: tableName, keepFavorites: keepFavorites);
    refreshSavedQueries(tableName: tableName);
  }
}

final queryProvider = StateNotifierProvider<QueryNotifier, QueryState>((ref) {
  final engine = ref.watch(databaseEngineProvider);
  return QueryNotifier(engine, ref);
});

class ChartConfigNotifier extends StateNotifier<ChartConfig?> {
  ChartConfigNotifier() : super(null);

  void updateConfig(ChartConfig config) {
    state = config;
  }

  void autoConfigure(QueryResult result) {
    if (result.columns.isEmpty || result.rows.isEmpty) {
      state = null;
      return;
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

    state = ChartConfig(
      type: ChartType.bar,
      labelColumn: candidateLabel,
      valueColumn: candidateValue,
    );
  }
}

final chartConfigProvider = StateNotifierProvider<ChartConfigNotifier, ChartConfig?>((ref) {
  return ChartConfigNotifier();
});
