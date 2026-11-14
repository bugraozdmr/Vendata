class SavedQuery {
  final int id;
  final String queryText;
  final String? title;
  final String? tableName;
  final String? sourceFile;
  final DateTime executedAt;
  final bool isFavorite;
  final int executionTimeMs;
  final int rowCount;

  const SavedQuery({
    required this.id,
    required this.queryText,
    this.title,
    this.tableName,
    this.sourceFile,
    required this.executedAt,
    this.isFavorite = false,
    this.executionTimeMs = 0,
    this.rowCount = 0,
  });

  SavedQuery copyWith({
    int? id,
    String? queryText,
    String? title,
    String? tableName,
    String? sourceFile,
    DateTime? executedAt,
    bool? isFavorite,
    int? executionTimeMs,
    int? rowCount,
  }) {
    return SavedQuery(
      id: id ?? this.id,
      queryText: queryText ?? this.queryText,
      title: title ?? this.title,
      tableName: tableName ?? this.tableName,
      sourceFile: sourceFile ?? this.sourceFile,
      executedAt: executedAt ?? this.executedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      executionTimeMs: executionTimeMs ?? this.executionTimeMs,
      rowCount: rowCount ?? this.rowCount,
    );
  }

  factory SavedQuery.fromMap(Map<String, dynamic> map) {
    return SavedQuery(
      id: map['id'] as int? ?? 0,
      queryText: map['query_text'] as String? ?? '',
      title: map['title'] as String?,
      tableName: map['table_name'] as String?,
      sourceFile: map['source_file'] as String?,
      executedAt: DateTime.tryParse(map['executed_at']?.toString() ?? '') ?? DateTime.now(),
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      executionTimeMs: map['execution_time_ms'] as int? ?? 0,
      rowCount: map['row_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'query_text': queryText,
      'title': title,
      'table_name': tableName,
      'source_file': sourceFile,
      'executed_at': executedAt.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
      'execution_time_ms': executionTimeMs,
      'row_count': rowCount,
    };
  }
}

