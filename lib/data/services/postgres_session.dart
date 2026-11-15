import 'package:postgres/postgres.dart';

import '../../core/utils/sql_sanitizer.dart';
import '../../domain/models/db_connection.dart';
import '../../domain/models/query_result.dart';
import '../../domain/models/table_schema.dart';
import 'database_engine.dart';
import 'db_session.dart';

class PostgresSession extends DbSession {
  final DbConnection config;
  final DatabaseEngine? logger;

  Connection? _connection;

  PostgresSession(this.config, {this.logger}) {
    SqlSanitizer.setIdentifierQuote('"');
  }

  @override
  DbDialect get dialect => DbDialect.postgresql;

  @override
  String get label => config.name;

  Connection? get rawConnection => _connection;

  bool get isConnected => _connection?.isOpen ?? false;

  Future<Connection> _ensureConnection() async {
    final existing = _connection;
    if (existing != null && existing.isOpen) return existing;

    final connection = await Connection.open(
      Endpoint(
        host: config.host,
        port: config.port,
        database: config.database,
        username: config.username.isEmpty ? null : config.username,
        password: config.password.isEmpty ? null : config.password,
      ),
      settings: ConnectionSettings(
        sslMode: config.useSsl ? SslMode.require : SslMode.disable,
        connectTimeout: const Duration(seconds: 20),
        queryTimeout: const Duration(minutes: 5),
        applicationName: 'vendata',
      ),
    );
    _connection = connection;
    return connection;
  }

  @override
  Future<QueryResult> execute(
    String sql, {
    String? tableName,
    String? sourceFile,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final connection = await _ensureConnection();
      final result = await connection.execute(sql);
      stopwatch.stop();

      final isRead = result.schema.columns.isNotEmpty;
      if (isRead) {
        final columns = <String>[];
        for (var i = 0; i < result.schema.columns.length; i++) {
          columns.add(result.schema.columns[i].columnName ?? 'sutun_${i + 1}');
        }
        final rows = result.map((row) => List<dynamic>.from(row)).toList();

        logger?.recordQuery(
          sql,
          tableName: tableName,
          sourceFile: sourceFile,
          executionTimeMs: stopwatch.elapsedMilliseconds,
          rowCount: rows.length,
        );

        return QueryResult(
          columns: columns,
          rows: rows,
          executionTimeMs: stopwatch.elapsedMilliseconds,
          query: sql,
        );
      }

      final affected = result.affectedRows;
      logger?.recordQuery(
        sql,
        tableName: tableName,
        sourceFile: sourceFile,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        rowCount: affected,
      );

      return QueryResult(
        columns: const ['durum', 'etkilenen_satir'],
        rows: [
          ['Başarılı', affected],
        ],
        executionTimeMs: stopwatch.elapsedMilliseconds,
        query: sql,
      );
    } catch (e) {
      stopwatch.stop();
      return QueryResult.withError(e.toString(), sql);
    }
  }

  @override
  Future<List<TableSchema>> getTables() async {
    final connection = await _ensureConnection();
    final tablesResult = await connection.execute(
      "SELECT table_name FROM information_schema.tables "
      "WHERE table_schema = current_schema() AND table_type = 'BASE TABLE' "
      'ORDER BY table_name ASC;',
    );
    final tableNames = tablesResult.map((row) => row[0]?.toString() ?? '').where((n) => n.isNotEmpty).toList();
    final fetchCounts = tableNames.length <= 100;

    final schemas = <TableSchema>[];
    for (final tableName in tableNames) {
      final columns = <ColumnInfo>[];
      try {
        final columnsResult = await connection.execute(
          'SELECT column_name, data_type FROM information_schema.columns '
          "WHERE table_schema = current_schema() AND table_name = '${_escapeLiteral(tableName)}' "
          'ORDER BY ordinal_position ASC;',
        );
        for (final row in columnsResult) {
          columns.add(
            ColumnInfo(
              name: row[0]?.toString() ?? '',
              type: normalizeColumnType(row[1]?.toString() ?? 'text'),
            ),
          );
        }
      } catch (_) {}

      final rowCount = fetchCounts ? await _countRows(connection, tableName) : 0;

      schemas.add(
        TableSchema(
          name: tableName,
          columns: columns,
          rowCount: rowCount,
        ),
      );
    }
    return schemas;
  }

  Future<int> _countRows(Connection connection, String tableName) async {
    try {
      final quoted = quoteIdentifier(tableName);
      final res = await connection.execute('SELECT COUNT(*) FROM $quoted;');
      if (res.isNotEmpty) {
        final value = res.first[0];
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  @override
  Future<void> test() async {
    final connection = await _ensureConnection();
    await connection.execute('SELECT 1;');
  }

  @override
  Future<void> close() async {
    final connection = _connection;
    _connection = null;
    if (connection != null && connection.isOpen) {
      await connection.close();
    }
  }

  static String _escapeLiteral(String value) => value.replaceAll("'", "''");
}
