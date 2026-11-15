import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sql_sanitizer.dart';
import '../../data/services/db_session.dart';
import '../../data/services/db_session_factory.dart';
import '../../data/services/database_engine.dart';
import '../../domain/models/db_connection.dart';
import 'database_provider.dart';

class ConnectionsState {
  final List<DbConnection> connections;
  final DbConnection? activeConnection;
  final bool isConnecting;
  final String? errorMessage;

  const ConnectionsState({
    this.connections = const [],
    this.activeConnection,
    this.isConnecting = false,
    this.errorMessage,
  });

  bool get isRemote => activeConnection != null;

  ConnectionsState copyWith({
    List<DbConnection>? connections,
    DbConnection? activeConnection,
    bool? isConnecting,
    String? errorMessage,
    bool clearActive = false,
    bool clearError = false,
  }) {
    return ConnectionsState(
      connections: connections ?? this.connections,
      activeConnection: clearActive ? null : (activeConnection ?? this.activeConnection),
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ConnectionsNotifier extends StateNotifier<ConnectionsState> {
  final DatabaseEngine _engine;

  ConnectionsNotifier(this._engine)
      : super(ConnectionsState(connections: _engine.getConnections()));

  void refresh() {
    state = state.copyWith(connections: _engine.getConnections());
  }

  String _newId() {
    return 'conn_${DateTime.now().microsecondsSinceEpoch}';
  }

  DbConnection buildConnection({
    String? id,
    required String name,
    required DbType type,
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    required bool useSsl,
  }) {
    return DbConnection(
      id: id ?? _newId(),
      name: name.trim().isEmpty ? type.label : name.trim(),
      type: type,
      host: host.trim(),
      port: port,
      database: database.trim(),
      username: username.trim(),
      password: password,
      useSsl: useSsl,
      createdAt: DateTime.now(),
    );
  }

  void save(DbConnection connection) {
    _engine.saveConnection(connection);
    refresh();

    if (state.activeConnection?.id == connection.id) {
      state = state.copyWith(activeConnection: connection);
    }
  }

  void delete(String id) {
    _engine.deleteConnection(id);
    if (state.activeConnection?.id == id) {
      state = state.copyWith(clearActive: true);
    }
    refresh();
  }

  Future<String?> test(DbConnection connection) async {
    final previousQuote = SqlSanitizer.identifierQuote;
    final session = createRemoteSession(connection);
    try {
      await session.test();
      return null;
    } catch (e) {
      return _friendlyError(e);
    } finally {
      await session.close();
      SqlSanitizer.setIdentifierQuote(previousQuote);
    }
  }

  Future<bool> connect(DbConnection connection) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    final previousQuote = SqlSanitizer.identifierQuote;
    final session = createRemoteSession(connection);
    try {
      await session.test();
      state = state.copyWith(
        isConnecting: false,
        activeConnection: connection,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: _friendlyError(e),
      );
      return false;
    } finally {
      await session.close();
      // On success the session provider will build a fresh session and set the
      // right quote. On failure make sure we restore the active dialect.
      if (state.activeConnection?.id != connection.id) {
        SqlSanitizer.setIdentifierQuote(previousQuote);
      }
    }
  }

  void disconnect() {
    state = state.copyWith(clearActive: true, clearError: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('SocketException') || message.contains('Connection refused')) {
      return 'Sunucuya ulaşılamadı. Host, port ve ağ bağlantısını kontrol edin.\n$message';
    }
    if (message.contains('password') || message.contains('authentication') || message.contains('Access denied')) {
      return 'Kimlik doğrulama başarısız. Kullanıcı adı ve şifreyi kontrol edin.\n$message';
    }
    return message;
  }
}

final connectionsProvider =
    StateNotifierProvider<ConnectionsNotifier, ConnectionsState>((ref) {
  final engine = ref.watch(databaseEngineProvider);
  return ConnectionsNotifier(engine);
});

/// The session used by all query/table operations. When no remote connection is
/// active this is the local SQLite engine, otherwise a lazily-connected remote
/// session.
final sessionProvider = Provider<DbSession>((ref) {
  final engine = ref.watch(databaseEngineProvider);
  final connection = ref.watch(
    connectionsProvider.select((state) => state.activeConnection),
  );

  if (connection == null) {
    return LocalDbSession(engine);
  }

  final session = createRemoteSession(connection, logger: engine);
  ref.onDispose(() => session.close());
  return session;
});
