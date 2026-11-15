import 'package:mysql_client/mysql_client.dart';
import 'package:mysql_client/mysql_protocol.dart';

import '../../core/utils/sql_sanitizer.dart';
import '../../domain/models/db_connection.dart';
import '../../domain/models/query_result.dart';
import '../../domain/models/table_schema.dart';
import 'database_engine.dart';
import 'db_session.dart';

class MySqlSession extends DbSession {
  final DbConnection config;
  final DatabaseEngine? logger;

  MySQLConnection? _connection;

  MySqlSession(this.config, {this.logger}) {
    SqlSanitizer.setIdentifierQuote('`');
  }

  @override
  DbDialect get dialect => DbDialect.mysql;

  @override
  String get label => config.name;

  bool get isConnected => _connection?.connected ?? false;

  Future<MySQLConnection> _ensureConnection() async {
    final existing = _connection;
    if (existing != null && existing.connected) return existing;

    final connection = await MySQLConnection.createConnection(
      host: config.host,
      port: config.port,
      userName: config.username,
      password: config.password,
      databaseName: config.database.isEmpty ? null : config.database,
      secure: config.useSsl,
    );
    await connection.connect();
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

      final columnList = result.cols.toList();
      if (columnList.isNotEmpty) {
        final columns = columnList.map((c) => c.name).toList();
        final rows = <List<dynamic>>[];
        for (final row in result.rows) {
          final values = <dynamic>[];
          for (var i = 0; i < columnList.length; i++) {
            values.add(_convertValue(row, i, columnList[i]));
          }
          rows.add(values);
        }

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

      final affected = result.affectedRows.toInt();
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

  dynamic _convertValue(ResultSetRow row, int index, ResultSetColumn column) {
    final raw = row.colAt(index);
    if (raw == null) return null;

    switch (column.type.intVal) {
      case mysqlColumnTypeTiny:
      case mysqlColumnTypeShort:
      case mysqlColumnTypeLong:
      case mysqlColumnTypeLongLong:
      case mysqlColumnTypeInt24:
      case mysqlColumnTypeYear:
        return int.tryParse(raw) ?? raw;
      case mysqlColumnTypeFloat:
      case mysqlColumnTypeDouble:
        return double.tryParse(raw) ?? raw;
      case mysqlColumnTypeDecimal:
      case mysqlColumnTypeNewDecimal:
        return num.tryParse(raw) ?? raw;
      default:
        return raw;
    }
  }

  @override
  Future<List<TableSchema>> getTables() async {
    final connection = await _ensureConnection();
    final tablesResult = await connection.execute(
      'SELECT TABLE_NAME FROM information_schema.tables '
      "WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE' "
      'ORDER BY TABLE_NAME ASC;',
    );
    final tableNames = tablesResult.rows.map((row) => row.colAt(0) ?? '').where((n) => n.isNotEmpty).toList();
    final fetchCounts = tableNames.length <= 100;

    final schemas = <TableSchema>[];
    for (final tableName in tableNames) {
      final columns = <ColumnInfo>[];
      try {
        final columnsResult = await connection.execute(
          'SELECT COLUMN_NAME, DATA_TYPE FROM information_schema.columns '
          "WHERE table_schema = DATABASE() AND table_name = '${_escapeLiteral(tableName)}' "
          'ORDER BY ORDINAL_POSITION ASC;',
        );
        for (final row in columnsResult.rows) {
          columns.add(
            ColumnInfo(
              name: row.colAt(0) ?? '',
              type: normalizeColumnType(row.colAt(1) ?? 'text'),
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

  Future<int> _countRows(MySQLConnection connection, String tableName) async {
    try {
      final quoted = quoteIdentifier(tableName);
      final res = await connection.execute('SELECT COUNT(*) FROM $quoted;');
      if (res.rows.isNotEmpty) {
        final raw = res.rows.first.colAt(0);
        return int.tryParse(raw ?? '') ?? 0;
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
    if (connection != null) {
      try {
        await connection.close();
      } catch (_) {}
    }
  }

  static String _escapeLiteral(String value) => value.replaceAll("'", "''");
}
