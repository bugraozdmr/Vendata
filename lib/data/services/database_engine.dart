import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/ai_providers_constants.dart';
import '../../core/utils/sql_sanitizer.dart';
import '../../domain/models/ai_chat_model.dart';
import '../../domain/models/ai_provider.dart';
import '../../domain/models/db_connection.dart';
import '../../domain/models/query_result.dart';
import '../../domain/models/recent_file.dart';
import '../../domain/models/saved_query.dart';
import '../../domain/models/table_schema.dart';
import '../datasources/csv_parser.dart';

class DatabaseEngine {
  late final Database _db;
  final String? dbPath;

  DatabaseEngine({this.dbPath}) {
    if (dbPath != null && dbPath!.isNotEmpty) {
      _db = sqlite3.open(dbPath!);
    } else {
      _db = sqlite3.openInMemory();
    }
    _initSystemTables();
  }

  void _initSystemTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS _vendata_table_meta (
        table_name TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        last_accessed_at TEXT NOT NULL,
        row_count INTEGER DEFAULT 0,
        source_file TEXT
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS _vendata_recent_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        imported_at TEXT NOT NULL,
        tables_count INTEGER DEFAULT 1,
        total_rows INTEGER DEFAULT 0
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS _vendata_saved_queries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query_text TEXT NOT NULL,
        title TEXT,
        table_name TEXT,
        source_file TEXT,
        executed_at TEXT NOT NULL,
        is_favorite INTEGER DEFAULT 0,
        execution_time_ms INTEGER DEFAULT 0,
        row_count INTEGER DEFAULT 0
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS _vendata_connections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER NOT NULL,
        database_name TEXT,
        username TEXT,
        password TEXT,
        use_ssl INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS _vendata_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS _vendata_ai_providers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        provider_type TEXT NOT NULL,
        model_name TEXT NOT NULL,
        api_key TEXT NOT NULL,
        base_url TEXT,
        is_active INTEGER DEFAULT 0,
        is_predefined INTEGER DEFAULT 0,
        custom_models TEXT DEFAULT ''
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS _vendata_ai_conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        table_name TEXT,
        is_pinned INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    try {
      _db.execute('ALTER TABLE _vendata_ai_conversations ADD COLUMN is_pinned INTEGER DEFAULT 0;');
    } catch (_) {}

    _db.execute('''
      CREATE TABLE IF NOT EXISTS _vendata_ai_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        sql_query TEXT,
        result_json TEXT,
        chart_type TEXT,
        chart_x TEXT,
        chart_y TEXT,
        intent TEXT,
        execution_time_ms INTEGER DEFAULT 0,
        row_count INTEGER DEFAULT 0,
        error_message TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    _migrateSavedQueriesTable();
    _seedInitialConnections();
    _seedInitialAiProviders();
  }

  void _seedInitialConnections() {
    try {
      final existing = _db.select('SELECT id FROM _vendata_connections WHERE id IN (?, ?);', [
        'conn_infinityfree_health2care',
        'conn_neon_neondb',
      ]);
      final existingIds = existing.map((r) => r['id'] as String).toSet();

      if (!existingIds.contains('conn_infinityfree_health2care')) {
        saveConnection(DbConnection(
          id: 'conn_infinityfree_health2care',
          name: 'InfinityFree (health2care)',
          type: DbType.mysql,
          host: 'sql113.infinityfree.com',
          port: 3306,
          database: 'if0_42943365_health2care',
          username: 'if0_42943365',
          password: '781cjMuTGbtTZm',
          useSsl: false,
          createdAt: DateTime(2026, 1, 1),
        ));
      }

      if (!existingIds.contains('conn_neon_neondb')) {
        saveConnection(DbConnection(
          id: 'conn_neon_neondb',
          name: 'Neon DB (neondb)',
          type: DbType.postgresql,
          host: 'ep-mute-field-aezobwer-pooler.c-2.us-east-2.aws.neon.tech',
          port: 5432,
          database: 'neondb',
          username: 'neondb_owner',
          password: 'npg_8YoOEpPFd0DS',
          useSsl: true,
          createdAt: DateTime(2026, 1, 2),
        ));
      }
    } catch (_) {}
  }

  String? getSetting(String key) {
    try {
      final res = _db.select('SELECT value FROM _vendata_settings WHERE key = ? LIMIT 1;', [key]);
      if (res.isEmpty) return null;
      return res.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  void setSetting(String key, String value) {
    _db.execute(
      '''
      INSERT INTO _vendata_settings (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
      ''',
      [key, value],
    );
  }

  void _migrateSavedQueriesTable() {
    try {
      final info = _db.select('PRAGMA table_info(_vendata_saved_queries);');
      final existingCols = info.map((r) => r['name'] as String).toSet();

      if (!existingCols.contains('table_name')) {
        _db.execute('ALTER TABLE _vendata_saved_queries ADD COLUMN table_name TEXT;');
      }
      if (!existingCols.contains('source_file')) {
        _db.execute('ALTER TABLE _vendata_saved_queries ADD COLUMN source_file TEXT;');
      }
      if (!existingCols.contains('execution_time_ms')) {
        _db.execute('ALTER TABLE _vendata_saved_queries ADD COLUMN execution_time_ms INTEGER DEFAULT 0;');
      }
      if (!existingCols.contains('row_count')) {
        _db.execute('ALTER TABLE _vendata_saved_queries ADD COLUMN row_count INTEGER DEFAULT 0;');
      }
    } catch (_) {}
  }

  void importDataset(ParsedDataset dataset, {String? sourceFileName}) {
    if (dataset.headers.isEmpty) return;

    final tableName = SqlSanitizer.sanitizeTableName(dataset.name);
    final columns = SqlSanitizer.sanitizeColumnNames(dataset.headers);
    final colTypes = _inferTypes(columns.length, dataset.rows);

    _db.execute('DROP TABLE IF EXISTS ${SqlSanitizer.escapeIdentifier(tableName)};');

    final colDefs = <String>[];
    for (var i = 0; i < columns.length; i++) {
      colDefs.add('${SqlSanitizer.escapeIdentifier(columns[i])} ${colTypes[i]}');
    }

    _db.execute('CREATE TABLE ${SqlSanitizer.escapeIdentifier(tableName)} (${colDefs.join(', ')});');

    final nowStr = DateTime.now().toIso8601String();
    _db.execute(
      '''
      INSERT INTO _vendata_table_meta (table_name, created_at, last_accessed_at, row_count, source_file)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(table_name) DO UPDATE SET
        last_accessed_at = excluded.last_accessed_at,
        row_count = excluded.row_count,
        source_file = excluded.source_file;
      ''',
      [tableName, nowStr, nowStr, dataset.rows.length, sourceFileName ?? dataset.name],
    );

    if (dataset.rows.isEmpty) return;

    final placeholders = List.filled(columns.length, '?').join(', ');
    final insertSql = 'INSERT INTO ${SqlSanitizer.escapeIdentifier(tableName)} VALUES ($placeholders);';

    _db.execute('BEGIN TRANSACTION;');
    final stmt = _db.prepare(insertSql);
    try {
      for (final row in dataset.rows) {
        final paddedRow = List<dynamic>.filled(columns.length, null);
        for (var i = 0; i < columns.length && i < row.length; i++) {
          final val = row[i];
          if (val == null || val == '') {
            paddedRow[i] = null;
          } else if (colTypes[i] == 'INTEGER' && val is! int) {
            paddedRow[i] = int.tryParse(val.toString()) ?? val;
          } else if (colTypes[i] == 'REAL' && val is! num) {
            paddedRow[i] = double.tryParse(val.toString()) ?? val;
          } else {
            paddedRow[i] = val;
          }
        }
        stmt.execute(paddedRow);
      }
    } finally {
      stmt.close();
      _db.execute('COMMIT;');
    }
  }

  void executeRawScript(String sqlScript) {
    _db.execute(sqlScript);
  }

  String? extractTableNameFromSql(String sql) {
    try {
      final match = RegExp(r'(?:FROM|JOIN|INTO|UPDATE)\s+["`]?([a-zA-Z0-9_]+)["`]?', caseSensitive: false).firstMatch(sql);
      if (match != null && match.groupCount >= 1) {
        final t = match.group(1);
        if (t != null && !t.startsWith('_vendata_') && !t.startsWith('sqlite_')) {
          return t;
        }
      }
    } catch (_) {}
    return null;
  }

  QueryResult executeQuery(
    String sql, {
    String? tableName,
    String? sourceFile,
    bool logQuery = true,
  }) {
    final trimmed = sql.trim();
    if (trimmed.isEmpty) return QueryResult.empty();

    final stopwatch = Stopwatch()..start();
    try {
      final isSelect = trimmed.toUpperCase().startsWith('SELECT') ||
          trimmed.toUpperCase().startsWith('WITH') ||
          trimmed.toUpperCase().startsWith('PRAGMA') ||
          trimmed.toUpperCase().startsWith('EXPLAIN');

      if (isSelect) {
        final resultSet = _db.select(sql);
        stopwatch.stop();

        final rows = <List<dynamic>>[];
        for (final row in resultSet) {
          rows.add(List<dynamic>.from(row.values));
        }

        if (logQuery) {
          _logQuery(
            sql,
            tableName: tableName,
            sourceFile: sourceFile,
            executionTimeMs: stopwatch.elapsedMilliseconds,
            rowCount: rows.length,
          );
        }

        return QueryResult(
          columns: resultSet.columnNames,
          rows: rows,
          executionTimeMs: stopwatch.elapsedMilliseconds,
          query: sql,
        );
      } else {
        _db.execute(sql);
        stopwatch.stop();

        if (logQuery) {
          _logQuery(
            sql,
            tableName: tableName,
            sourceFile: sourceFile,
            executionTimeMs: stopwatch.elapsedMilliseconds,
            rowCount: _db.updatedRows,
          );
        }

        return QueryResult(
          columns: ['durum', 'etkilenen_satir'],
          rows: [
            ['Başarılı', _db.updatedRows]
          ],
          executionTimeMs: stopwatch.elapsedMilliseconds,
          query: sql,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return QueryResult.withError(e.toString(), sql);
    }
  }

  void _logQuery(
    String sql, {
    String? tableName,
    String? sourceFile,
    int executionTimeMs = 0,
    int rowCount = 0,
  }) {
    try {
      final targetTable = tableName ?? extractTableNameFromSql(sql);
      String? targetSource = sourceFile;

      if (targetSource == null && targetTable != null) {
        try {
          final meta = _db.select('SELECT source_file FROM _vendata_table_meta WHERE table_name = ? LIMIT 1;', [targetTable]);
          if (meta.isNotEmpty) {
            targetSource = meta.first['source_file']?.toString();
          }
        } catch (_) {}
      }

      _db.execute(
        '''
        INSERT INTO _vendata_saved_queries (query_text, table_name, source_file, executed_at, is_favorite, execution_time_ms, row_count)
        VALUES (?, ?, ?, ?, 0, ?, ?);
        ''',
        [
          sql.trim(),
          targetTable,
          targetSource,
          DateTime.now().toIso8601String(),
          executionTimeMs,
          rowCount,
        ],
      );
    } catch (_) {}
  }

  void recordQuery(
    String sql, {
    String? tableName,
    String? sourceFile,
    int executionTimeMs = 0,
    int rowCount = 0,
  }) {
    _logQuery(
      sql,
      tableName: tableName,
      sourceFile: sourceFile,
      executionTimeMs: executionTimeMs,
      rowCount: rowCount,
    );
  }

  List<SavedQuery> getSavedQueries({String? tableName, bool? onlyFavorites, int limit = 50}) {
    try {
      var query = 'SELECT * FROM _vendata_saved_queries';
      final conditions = <String>[];
      final params = <dynamic>[];

      if (tableName != null && tableName.isNotEmpty) {
        conditions.add('table_name = ?');
        params.add(tableName);
      }
      if (onlyFavorites == true) {
        conditions.add('is_favorite = 1');
      }

      if (conditions.isNotEmpty) {
        query += ' WHERE ${conditions.join(' AND ')}';
      }

      query += ' ORDER BY is_favorite DESC, id DESC LIMIT ?;';
      params.add(limit);

      final res = _db.select(query, params);
      return res.map((r) => SavedQuery.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  void toggleQueryFavorite(int id) {
    try {
      _db.execute(
        'UPDATE _vendata_saved_queries SET is_favorite = (CASE WHEN is_favorite = 1 THEN 0 ELSE 1 END) WHERE id = ?;',
        [id],
      );
    } catch (_) {}
  }

  Set<String> getFavoriteSqls() {
    try {
      final res = _db.select(
        'SELECT DISTINCT query_text FROM _vendata_saved_queries WHERE is_favorite = 1;',
      );
      return res
          .map((r) => (r['query_text'] as String? ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  bool isQueryFavorite(String sql) {
    try {
      final trimmed = sql.trim();
      if (trimmed.isEmpty) return false;
      final res = _db.select(
        'SELECT 1 FROM _vendata_saved_queries WHERE query_text = ? AND is_favorite = 1 LIMIT 1;',
        [trimmed],
      );
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void setQueryFavoriteBySql(
    String sql, {
    required bool favorite,
    String? tableName,
  }) {
    try {
      final trimmed = sql.trim();
      if (trimmed.isEmpty) return;

      final existing = _db.select(
        'SELECT id FROM _vendata_saved_queries WHERE query_text = ? ORDER BY id DESC LIMIT 1;',
        [trimmed],
      );

      if (existing.isEmpty) {
        if (!favorite) return;
        _logQuery(trimmed, tableName: tableName);
      }

      _db.execute(
        'UPDATE _vendata_saved_queries SET is_favorite = ? WHERE query_text = ?;',
        [favorite ? 1 : 0, trimmed],
      );
    } catch (_) {}
  }

  void deleteSavedQuery(int id) {
    try {
      _db.execute('DELETE FROM _vendata_saved_queries WHERE id = ?;', [id]);
    } catch (_) {}
  }

  List<String> getQueryHistory({String? tableName}) {
    try {
      if (tableName != null && tableName.isNotEmpty) {
        final res = _db.select(
          'SELECT DISTINCT query_text FROM _vendata_saved_queries WHERE table_name = ? ORDER BY id DESC LIMIT 30;',
          [tableName],
        );
        return res.map((r) => r['query_text'] as String).toList();
      }
      final res = _db.select('SELECT DISTINCT query_text FROM _vendata_saved_queries ORDER BY id DESC LIMIT 30;');
      return res.map((r) => r['query_text'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  void clearQueryHistory({String? tableName, bool keepFavorites = true}) {
    try {
      if (tableName != null && tableName.isNotEmpty) {
        if (keepFavorites) {
          _db.execute('DELETE FROM _vendata_saved_queries WHERE table_name = ? AND is_favorite = 0;', [tableName]);
        } else {
          _db.execute('DELETE FROM _vendata_saved_queries WHERE table_name = ?;', [tableName]);
        }
      } else {
        if (keepFavorites) {
          _db.execute('DELETE FROM _vendata_saved_queries WHERE is_favorite = 0;');
        } else {
          _db.execute('DELETE FROM _vendata_saved_queries;');
        }
      }
    } catch (_) {}
  }

  void markTableAccessed(String tableName) {
    try {
      _db.execute(
        'UPDATE _vendata_table_meta SET last_accessed_at = ? WHERE table_name = ?;',
        [DateTime.now().toIso8601String(), tableName],
      );
    } catch (_) {}
  }

  void addOrUpdateRecentFile(RecentFile file) {
    _db.execute('DELETE FROM _vendata_recent_files WHERE file_path = ?;', [file.filePath]);
    _db.execute(
      '''
      INSERT INTO _vendata_recent_files (file_name, file_path, file_type, file_size, imported_at, tables_count, total_rows)
      VALUES (?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        file.fileName,
        file.filePath,
        file.fileType,
        file.fileSize,
        file.importedAt.toIso8601String(),
        file.tablesCount,
        file.totalRows,
      ],
    );
  }

  List<RecentFile> getRecentFiles() {
    try {
      final res = _db.select('SELECT * FROM _vendata_recent_files ORDER BY id DESC LIMIT 15;');
      return res.map((r) => RecentFile.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  void deleteRecentFile(int id) {
    _db.execute('DELETE FROM _vendata_recent_files WHERE id = ?;', [id]);
  }

  void clearRecentFiles() {
    _db.execute('DELETE FROM _vendata_recent_files;');
  }

  List<DbConnection> getConnections() {
    try {
      final res = _db.select('SELECT * FROM _vendata_connections ORDER BY created_at ASC;');
      return res.map((r) => DbConnection.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  void saveConnection(DbConnection connection) {
    final map = connection.toMap();
    _db.execute(
      '''
      INSERT INTO _vendata_connections (id, name, type, host, port, database_name, username, password, use_ssl, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        type = excluded.type,
        host = excluded.host,
        port = excluded.port,
        database_name = excluded.database_name,
        username = excluded.username,
        password = excluded.password,
        use_ssl = excluded.use_ssl;
      ''',
      [
        map['id'],
        map['name'],
        map['type'],
        map['host'],
        map['port'],
        map['database_name'],
        map['username'],
        map['password'],
        map['use_ssl'],
        map['created_at'],
      ],
    );
  }

  void deleteConnection(String id) {
    _db.execute('DELETE FROM _vendata_connections WHERE id = ?;', [id]);
  }

  DbConnection? getConnection(String id) {
    try {
      final res = _db.select('SELECT * FROM _vendata_connections WHERE id = ? LIMIT 1;', [id]);
      if (res.isEmpty) return null;
      return DbConnection.fromMap(res.first);
    } catch (_) {
      return null;
    }
  }

  List<TableSchema> getTables() {
    final tablesResult = _db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_vendata_%' ORDER BY name ASC;",
    );

    final schemas = <TableSchema>[];
    for (final row in tablesResult) {
      final tableName = row['name'] as String;

      final infoResult = _db.select('PRAGMA table_info(${SqlSanitizer.escapeIdentifier(tableName)});');
      final columns = <ColumnInfo>[];
      for (final colRow in infoResult) {
        columns.add(
          ColumnInfo(
            name: colRow['name'] as String,
            type: colRow['type'] as String? ?? 'TEXT',
          ),
        );
      }

      final countResult = _db.select('SELECT COUNT(*) as cnt FROM ${SqlSanitizer.escapeIdentifier(tableName)};');
      final count = countResult.first['cnt'] as int? ?? 0;

      DateTime? createdAt;
      DateTime? lastAccessedAt;
      String? sourceFile;

      try {
        final metaResult = _db.select(
          'SELECT created_at, last_accessed_at, source_file FROM _vendata_table_meta WHERE table_name = ? LIMIT 1;',
          [tableName],
        );
        if (metaResult.isNotEmpty) {
          final m = metaResult.first;
          createdAt = DateTime.tryParse(m['created_at']?.toString() ?? '');
          lastAccessedAt = DateTime.tryParse(m['last_accessed_at']?.toString() ?? '');
          sourceFile = m['source_file']?.toString();
        }
      } catch (_) {}

      schemas.add(
        TableSchema(
          name: tableName,
          columns: columns,
          rowCount: count,
          createdAt: createdAt,
          lastAccessedAt: lastAccessedAt,
          sourceFile: sourceFile,
        ),
      );
    }
    return schemas;
  }

  void dropTable(String tableName) {
    _db.execute('DROP TABLE IF EXISTS ${SqlSanitizer.escapeIdentifier(tableName)};');
    try {
      _db.execute('DELETE FROM _vendata_table_meta WHERE table_name = ?;', [tableName]);
    } catch (_) {}
  }

  void clearAll() {
    final tables = getTables();
    for (final t in tables) {
      dropTable(t.name);
    }
    clearRecentFiles();
  }

  int getDatabaseSizeBytes() {
    if (dbPath != null && dbPath!.isNotEmpty) {
      final f = File(dbPath!);
      if (f.existsSync()) {
        return f.lengthSync();
      }
    }
    return 0;
  }

  List<String> _inferTypes(int colCount, List<List<dynamic>> sampleRows) {
    final types = List<String>.filled(colCount, 'INTEGER');
    final checkLimit = sampleRows.length > 50 ? 50 : sampleRows.length;

    for (var colIdx = 0; colIdx < colCount; colIdx++) {
      var isInt = true;
      var isReal = true;
      var hasNonNull = false;

      for (var rowIdx = 0; rowIdx < checkLimit; rowIdx++) {
        final row = sampleRows[rowIdx];
        if (colIdx >= row.length) continue;
        final val = row[colIdx];
        if (val == null || val == '') continue;

        hasNonNull = true;
        if (val is int) {
          continue;
        } else if (val is double) {
          isInt = false;
        } else {
          final str = val.toString().trim();
          if (int.tryParse(str) == null) {
            isInt = false;
            if (double.tryParse(str) == null) {
              isReal = false;
              break;
            }
          }
        }
      }

      if (!hasNonNull || (!isInt && !isReal)) {
        types[colIdx] = 'TEXT';
      } else if (isInt) {
        types[colIdx] = 'INTEGER';
      } else {
        types[colIdx] = 'REAL';
      }
    }
    return types;
  }

  // --- AI Providers & Settings ---

  void _seedInitialAiProviders() {
    try {
      final existing = _db.select('SELECT id FROM _vendata_ai_providers LIMIT 1;');
      if (existing.isNotEmpty) {
        // Upgrade any outdated/deprecated Gemini models to working gemini-3.5-flash-lite
        _db.execute('''
          UPDATE _vendata_ai_providers 
          SET model_name = 'gemini-3.5-flash-lite'
          WHERE provider_type = 'gemini' 
            AND (model_name LIKE '%2.0-flash%' OR model_name LIKE '%1.5-flash%' OR model_name LIKE '%2.5-flash%');
        ''');
        return;
      }

      final geminiKey = AppConfig.geminiApiKey;
      final openRouterKey = AppConfig.openRouterApiKey;
      final hasGeminiKey = geminiKey.trim().isNotEmpty;
      final hasOpenRouterKey = openRouterKey.trim().isNotEmpty;

      for (final preset in AIProvidersConstants.presets) {
        String key = '';
        bool isActive = false;
        if (preset.id == AIProvidersConstants.geminiId) {
          key = geminiKey;
          isActive = hasGeminiKey || !hasOpenRouterKey;
        } else if (preset.id == AIProvidersConstants.openrouterId) {
          key = openRouterKey;
          isActive = !hasGeminiKey && hasOpenRouterKey;
        }

        saveAiProvider(AIProviderModel(
          id: preset.id,
          name: preset.name,
          providerType: preset.providerType,
          modelName: preset.defaultModel,
          apiKey: key,
          baseUrl: preset.defaultBaseUrl,
          isActive: isActive,
          isPredefined: true,
          customModels: const [],
        ));
      }
    } catch (_) {}
  }

  List<AIProviderModel> getAiProviders() {
    try {
      final res = _db.select('SELECT * FROM _vendata_ai_providers ORDER BY is_predefined DESC, name ASC;');
      return res.map((r) => AIProviderModel.fromMap(Map<String, dynamic>.from(r))).toList();
    } catch (_) {
      return [];
    }
  }

  AIProviderModel? getActiveAiProvider() {
    try {
      final res = _db.select('SELECT * FROM _vendata_ai_providers WHERE is_active = 1 LIMIT 1;');
      if (res.isNotEmpty) {
        return AIProviderModel.fromMap(Map<String, dynamic>.from(res.first));
      }
      final all = getAiProviders();
      if (all.isEmpty) return null;
      return all.firstWhere((p) => p.apiKey.isNotEmpty, orElse: () => all.first);
    } catch (_) {
      return null;
    }
  }

  void saveAiProvider(AIProviderModel provider) {
    try {
      _db.execute(
        '''
        INSERT INTO _vendata_ai_providers (id, name, provider_type, model_name, api_key, base_url, is_active, is_predefined, custom_models)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          provider_type = excluded.provider_type,
          model_name = excluded.model_name,
          api_key = excluded.api_key,
          base_url = excluded.base_url,
          is_active = excluded.is_active,
          is_predefined = excluded.is_predefined,
          custom_models = excluded.custom_models;
        ''',
        [
          provider.id,
          provider.name,
          provider.providerType,
          provider.modelName,
          provider.apiKey,
          provider.baseUrl,
          provider.isActive ? 1 : 0,
          provider.isPredefined ? 1 : 0,
          provider.customModels.join(','),
        ],
      );
    } catch (_) {}
  }

  void setActiveAiProvider(String id) {
    try {
      _db.execute('UPDATE _vendata_ai_providers SET is_active = 0;');
      _db.execute('UPDATE _vendata_ai_providers SET is_active = 1 WHERE id = ?;', [id]);
    } catch (_) {}
  }

  void deleteAiProvider(String id) {
    try {
      _db.execute('DELETE FROM _vendata_ai_providers WHERE id = ? AND is_predefined = 0;', [id]);
    } catch (_) {}
  }

  // --- AI Conversations & Messages ---

  List<AiConversation> getAiConversations() {
    try {
      final res = _db.select('''
        SELECT c.*, COUNT(m.id) as message_count
        FROM _vendata_ai_conversations c
        LEFT JOIN _vendata_ai_messages m ON c.id = m.conversation_id
        GROUP BY c.id
        ORDER BY c.is_pinned DESC, c.updated_at DESC;
      ''');
      return res.map((r) {
        final map = Map<String, dynamic>.from(r);
        final count = (map['message_count'] as int?) ?? 0;
        return AiConversation.fromMap(map, messageCount: count);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void saveAiConversation(AiConversation conv) {
    try {
      _db.execute(
        '''
        INSERT INTO _vendata_ai_conversations (id, title, table_name, is_pinned, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          table_name = excluded.table_name,
          is_pinned = excluded.is_pinned,
          updated_at = excluded.updated_at;
        ''',
        [
          conv.id,
          conv.title,
          conv.tableName,
          conv.isPinned ? 1 : 0,
          conv.createdAt.toIso8601String(),
          conv.updatedAt.toIso8601String(),
        ],
      );
    } catch (_) {}
  }

  void updateAiConversationTitle(String id, String title) {
    try {
      _db.execute(
        'UPDATE _vendata_ai_conversations SET title = ?, updated_at = ? WHERE id = ?;',
        [title, DateTime.now().toIso8601String(), id],
      );
    } catch (_) {}
  }

  void toggleAiConversationPin(String id) {
    try {
      _db.execute(
        'UPDATE _vendata_ai_conversations SET is_pinned = CASE WHEN is_pinned = 1 THEN 0 ELSE 1 END WHERE id = ?;',
        [id],
      );
    } catch (_) {}
  }

  void deleteAiConversation(String id) {
    try {
      _db.execute('DELETE FROM _vendata_ai_messages WHERE conversation_id = ?;', [id]);
      _db.execute('DELETE FROM _vendata_ai_conversations WHERE id = ?;', [id]);
    } catch (_) {}
  }

  List<AiMessage> getAiMessages(String conversationId) {
    try {
      final res = _db.select(
        'SELECT * FROM _vendata_ai_messages WHERE conversation_id = ? ORDER BY created_at ASC;',
        [conversationId],
      );
      return res.map((r) => AiMessage.fromMap(Map<String, dynamic>.from(r))).toList();
    } catch (_) {
      return [];
    }
  }

  void saveAiMessage(AiMessage msg) {
    try {
      _db.execute(
        '''
        INSERT INTO _vendata_ai_messages (
          id, conversation_id, role, content, sql_query, result_json,
          chart_type, chart_x, chart_y, intent, execution_time_ms, row_count, error_message, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          msg.id,
          msg.conversationId,
          msg.role,
          msg.content,
          msg.sqlQuery,
          msg.resultJson,
          msg.chartType,
          msg.chartX,
          msg.chartY,
          msg.intent,
          msg.executionTimeMs,
          msg.rowCount,
          msg.errorMessage,
          msg.createdAt.toIso8601String(),
        ],
      );

      // Update conversation updated_at
      _db.execute(
        'UPDATE _vendata_ai_conversations SET updated_at = ? WHERE id = ?;',
        [DateTime.now().toIso8601String(), msg.conversationId],
      );
    } catch (_) {}
  }

  void deleteAiMessage(String id) {
    try {
      _db.execute('DELETE FROM _vendata_ai_messages WHERE id = ?;', [id]);
    } catch (_) {}
  }

  void close() {
    _db.close();
  }
}
