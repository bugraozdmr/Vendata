import '../../core/utils/sql_sanitizer.dart';
import '../../domain/models/query_result.dart';
import '../../domain/models/table_schema.dart';
import 'database_engine.dart';

enum DbDialect {
  sqlite,
  postgresql,
  mysql;

  String quoteIdentifier(String name) {
    switch (this) {
      case DbDialect.mysql:
        return '`${name.replaceAll('`', '``')}`';
      case DbDialect.sqlite:
      case DbDialect.postgresql:
        return '"${name.replaceAll('"', '""')}"';
    }
  }

  String get label {
    switch (this) {
      case DbDialect.sqlite:
        return 'SQLite';
      case DbDialect.postgresql:
        return 'PostgreSQL';
      case DbDialect.mysql:
        return 'MySQL';
    }
  }
}

/// Unified, asynchronous query interface used by the UI.
///
/// The local SQLite engine is synchronous, but remote engines are not. Wrapping
/// both behind a [Future] based API lets the rest of the app stay agnostic.
abstract class DbSession {
  DbDialect get dialect;

  String get label;

  bool get isRemote => dialect != DbDialect.sqlite;

  Future<QueryResult> execute(
    String sql, {
    String? tableName,
    String? sourceFile,
    bool logQuery = true,
  });

  Future<List<TableSchema>> getTables();

  Future<void> test();

  Future<void> close();

  String quoteIdentifier(String name) => dialect.quoteIdentifier(name);
}

class LocalDbSession extends DbSession {
  final DatabaseEngine _engine;

  LocalDbSession(this._engine) {
    SqlSanitizer.setIdentifierQuote('"');
  }

  @override
  DbDialect get dialect => DbDialect.sqlite;

  @override
  String get label => 'Yerel (SQLite)';

  @override
  Future<QueryResult> execute(
    String sql, {
    String? tableName,
    String? sourceFile,
    bool logQuery = true,
  }) async {
    return _engine.executeQuery(
      sql,
      tableName: tableName,
      sourceFile: sourceFile,
      logQuery: logQuery,
    );
  }

  @override
  Future<List<TableSchema>> getTables() async {
    return _engine.getTables();
  }

  @override
  Future<void> test() async {}

  @override
  Future<void> close() async {}
}

/// Maps a database native type name to the coarse type buckets used by the UI.
String normalizeColumnType(String rawType) {
  final type = rawType.toLowerCase();
  if (type.contains('int') ||
      type.contains('serial') ||
      type.contains('year') ||
      type.contains('bit') ||
      type.contains('bool')) {
    return 'INTEGER';
  }
  if (type.contains('real') ||
      type.contains('double') ||
      type.contains('float') ||
      type.contains('numeric') ||
      type.contains('decimal') ||
      type.contains('money')) {
    return 'REAL';
  }
  return 'TEXT';
}
