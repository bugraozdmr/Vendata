class ColumnInfo {
  final String name;
  final String type;

  const ColumnInfo({required this.name, required this.type});
}

class TableSchema {
  final String name;
  final List<ColumnInfo> columns;
  final int rowCount;
  final DateTime? createdAt;
  final DateTime? lastAccessedAt;
  final String? sourceFile;

  const TableSchema({
    required this.name,
    required this.columns,
    required this.rowCount,
    this.createdAt,
    this.lastAccessedAt,
    this.sourceFile,
  });

  List<String> get columnNames => columns.map((c) => c.name).toList();
}
