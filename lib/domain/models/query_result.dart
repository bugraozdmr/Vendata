class QueryResult {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final int executionTimeMs;
  final String? error;
  final String query;

  const QueryResult({
    required this.columns,
    required this.rows,
    required this.executionTimeMs,
    required this.query,
    this.error,
  });

  factory QueryResult.empty() {
    return const QueryResult(
      columns: [],
      rows: [],
      executionTimeMs: 0,
      query: '',
    );
  }

  factory QueryResult.withError(String error, String query) {
    return QueryResult(
      columns: const [],
      rows: const [],
      executionTimeMs: 0,
      query: query,
      error: error,
    );
  }

  bool get hasError => error != null && error!.isNotEmpty;
  bool get isEmpty => rows.isEmpty && !hasError;
  int get rowCount => rows.length;
}

