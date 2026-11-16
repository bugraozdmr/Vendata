enum DbType {
  postgresql,
  mysql;

  String get label {
    switch (this) {
      case DbType.postgresql:
        return 'PostgreSQL';
      case DbType.mysql:
        return 'MySQL / MariaDB';
    }
  }

  String get assetLogo {
    switch (this) {
      case DbType.postgresql:
        return 'assets/postgre.png';
      case DbType.mysql:
        return 'assets/mysql.png';
    }
  }

  String get storageKey => name;

  int get defaultPort {
    switch (this) {
      case DbType.postgresql:
        return 5432;
      case DbType.mysql:
        return 3306;
    }
  }

  static DbType fromStorage(String? value) {
    switch (value) {
      case 'mysql':
        return DbType.mysql;
      case 'postgresql':
      default:
        return DbType.postgresql;
    }
  }
}

class DbConnection {
  final String id;
  final String name;
  final DbType type;
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final bool useSsl;
  final DateTime createdAt;

  const DbConnection({
    required this.id,
    required this.name,
    required this.type,
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.useSsl,
    required this.createdAt,
  });

  String get endpoint => '$host:$port/$database';

  /// Parses a database URL such as
  /// `postgresql://user:pass@host:5432/db?sslmode=require` or
  /// `mysql://user:pass@host:3306/db`.
  ///
  /// Returns `null` when the string is not a supported connection URL.
  static DbConnection? tryParseUri(String raw, {String? fallbackName}) {
    final trimmed = raw.trim();
    if (!trimmed.contains('://')) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return null;

    final scheme = uri.scheme.toLowerCase();
    final DbType type;
    if (scheme.startsWith('postgres')) {
      type = DbType.postgresql;
    } else if (scheme == 'mysql' || scheme == 'mariadb') {
      type = DbType.mysql;
    } else {
      return null;
    }

    var username = '';
    var password = '';
    final userInfo = uri.userInfo;
    if (userInfo.isNotEmpty) {
      final separator = userInfo.indexOf(':');
      if (separator >= 0) {
        username = Uri.decodeComponent(userInfo.substring(0, separator));
        password = Uri.decodeComponent(userInfo.substring(separator + 1));
      } else {
        username = Uri.decodeComponent(userInfo);
      }
    }

    final segments = uri.pathSegments;
    final database = segments.isNotEmpty ? segments.first : '';

    final query = uri.queryParameters;
    final sslValue =
        (query['sslmode'] ?? query['ssl-mode'] ?? query['ssl'] ?? '').toLowerCase();
    final useSsl = sslValue.isNotEmpty
        ? !(sslValue == 'disable' ||
            sslValue == 'disabled' ||
            sslValue == 'false' ||
            sslValue == '0' ||
            sslValue == 'off')
        : false;

    final name = (fallbackName?.trim().isNotEmpty ?? false)
        ? fallbackName!.trim()
        : (database.isNotEmpty ? database : uri.host);

    return DbConnection(
      id: 'conn_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      type: type,
      host: uri.host,
      port: uri.hasPort ? uri.port : type.defaultPort,
      database: database,
      username: username,
      password: password,
      useSsl: useSsl,
      createdAt: DateTime.now(),
    );
  }

  DbConnection copyWith({
    String? id,
    String? name,
    DbType? type,
    String? host,
    int? port,
    String? database,
    String? username,
    String? password,
    bool? useSsl,
    DateTime? createdAt,
  }) {
    return DbConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      database: database ?? this.database,
      username: username ?? this.username,
      password: password ?? this.password,
      useSsl: useSsl ?? this.useSsl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory DbConnection.fromMap(Map<String, dynamic> map) {
    return DbConnection(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Bağlantı',
      type: DbType.fromStorage(map['type'] as String?),
      host: map['host'] as String? ?? 'localhost',
      port: (map['port'] as int?) ?? DbType.fromStorage(map['type'] as String?).defaultPort,
      database: map['database_name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      useSsl: (map['use_ssl'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.storageKey,
      'host': host,
      'port': port,
      'database_name': database,
      'username': username,
      'password': password,
      'use_ssl': useSsl ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DbConnection &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.host == host &&
        other.port == port &&
        other.database == database &&
        other.username == username &&
        other.password == password &&
        other.useSsl == useSsl;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        host,
        port,
        database,
        username,
        password,
        useSsl,
      );
}
