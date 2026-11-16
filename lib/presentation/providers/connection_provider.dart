import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sql_sanitizer.dart';
import '../../data/services/db_session.dart';
import '../../data/services/db_session_factory.dart';
import '../../data/services/database_engine.dart';
import '../../domain/models/db_connection.dart';
import 'database_provider.dart';

enum ConnectionHealthStatus { unknown, checking, online, offline }

class ConnectionHealth {
  final ConnectionHealthStatus status;
  final DateTime? checkedAt;
  final String? message;

  const ConnectionHealth({
    this.status = ConnectionHealthStatus.unknown,
    this.checkedAt,
    this.message,
  });

  bool get isOnline => status == ConnectionHealthStatus.online;
  bool get isOffline => status == ConnectionHealthStatus.offline;
  bool get isChecking => status == ConnectionHealthStatus.checking;
}

class ConnectionsState {
  final List<DbConnection> connections;
  final DbConnection? activeConnection;
  final bool isConnecting;
  final String? errorMessage;
  final Map<String, ConnectionHealth> health;

  const ConnectionsState({
    this.connections = const [],
    this.activeConnection,
    this.isConnecting = false,
    this.errorMessage,
    this.health = const {},
  });

  bool get isRemote => activeConnection != null;

  ConnectionHealth healthFor(String id) =>
      health[id] ?? const ConnectionHealth();

  ConnectionsState copyWith({
    List<DbConnection>? connections,
    DbConnection? activeConnection,
    bool? isConnecting,
    String? errorMessage,
    Map<String, ConnectionHealth>? health,
    bool clearActive = false,
    bool clearError = false,
  }) {
    return ConnectionsState(
      connections: connections ?? this.connections,
      activeConnection: clearActive ? null : (activeConnection ?? this.activeConnection),
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      health: health ?? this.health,
    );
  }
}

class ConnectionsNotifier extends StateNotifier<ConnectionsState> {
  final DatabaseEngine _engine;
  Timer? _healthTimer;
  final Set<String> _checksInFlight = {};

  /// How often saved connections are pinged in the background.
  static const Duration healthInterval = Duration(seconds: 45);

  ConnectionsNotifier(this._engine, {bool? autoHealthCheck})
      : super(ConnectionsState(connections: _engine.getConnections())) {
    final shouldAutoCheck = autoHealthCheck ?? (!Platform.environment.containsKey('FLUTTER_TEST'));
    if (shouldAutoCheck) {
      _healthTimer = Timer.periodic(healthInterval, (_) => checkAllHealth());
      Future.microtask(checkAllHealth);
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  void refresh() {
    final connections = _engine.getConnections();
    final validIds = connections.map((c) => c.id).toSet();
    final health = Map<String, ConnectionHealth>.from(state.health)
      ..removeWhere((id, _) => !validIds.contains(id));
    state = state.copyWith(connections: connections, health: health);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      Future.microtask(checkAllHealth);
    }
  }

  Future<void> checkAllHealth() async {
    final connections = state.connections;
    if (connections.isEmpty) return;
    await Future.wait(connections.map(checkHealth));
  }

  Future<void> checkHealth(DbConnection connection) async {
    if (_checksInFlight.contains(connection.id)) return;
    _checksInFlight.add(connection.id);

    _setHealth(
      connection.id,
      ConnectionHealth(
        status: ConnectionHealthStatus.checking,
        checkedAt: state.healthFor(connection.id).checkedAt,
      ),
    );

    final previousQuote = SqlSanitizer.identifierQuote;
    final session = createRemoteSession(connection);
    // Creating a remote session sets the global identifier quote; restore it
    // immediately so a background ping cannot affect query generation.
    SqlSanitizer.setIdentifierQuote(previousQuote);
    try {
      await session.test();
      _setHealth(
        connection.id,
        ConnectionHealth(
          status: ConnectionHealthStatus.online,
          checkedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      _setHealth(
        connection.id,
        ConnectionHealth(
          status: ConnectionHealthStatus.offline,
          checkedAt: DateTime.now(),
          message: _friendlyError(e),
        ),
      );
    } finally {
      await session.close();
      SqlSanitizer.setIdentifierQuote(previousQuote);
      _checksInFlight.remove(connection.id);
    }
  }

  void _setHealth(String id, ConnectionHealth health) {
    if (!mounted) return;
    if (!state.connections.any((c) => c.id == id)) return;
    final updated = Map<String, ConnectionHealth>.from(state.health)
      ..[id] = health;
    state = state.copyWith(health: updated);
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
      _setHealth(
        connection.id,
        ConnectionHealth(
          status: ConnectionHealthStatus.online,
          checkedAt: DateTime.now(),
        ),
      );
      return true;
    } catch (e) {
      final message = _friendlyError(e);
      state = state.copyWith(
        isConnecting: false,
        errorMessage: message,
      );
      _setHealth(
        connection.id,
        ConnectionHealth(
          status: ConnectionHealthStatus.offline,
          checkedAt: DateTime.now(),
          message: message,
        ),
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
