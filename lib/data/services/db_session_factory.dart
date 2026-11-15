import '../../domain/models/db_connection.dart';
import 'database_engine.dart';
import 'db_session.dart';
import 'mysql_session.dart';
import 'postgres_session.dart';

/// Creates a session for a remote connection. Sessions connect lazily on the
/// first query and store an optional [logger] so executed queries still appear
/// in the local Vendata history.
DbSession createRemoteSession(DbConnection connection, {DatabaseEngine? logger}) {
  switch (connection.type) {
    case DbType.postgresql:
      return PostgresSession(connection, logger: logger);
    case DbType.mysql:
      return MySqlSession(connection, logger: logger);
  }
}
