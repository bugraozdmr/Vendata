class RecentFile {
  final int? id;
  final String fileName;
  final String filePath;
  final String fileType;
  final int fileSize;
  final DateTime importedAt;
  final int tablesCount;
  final int totalRows;

  const RecentFile({
    this.id,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.importedAt,
    required this.tablesCount,
    required this.totalRows,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'file_name': fileName,
      'file_path': filePath,
      'file_type': fileType,
      'file_size': fileSize,
      'imported_at': importedAt.toIso8601String(),
      'tables_count': tablesCount,
      'total_rows': totalRows,
    };
  }

  factory RecentFile.fromMap(Map<String, dynamic> map) {
    return RecentFile(
      id: map['id'] as int?,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      fileType: map['file_type'] as String,
      fileSize: map['file_size'] as int,
      importedAt: DateTime.tryParse(map['imported_at'] as String) ?? DateTime.now(),
      tablesCount: map['tables_count'] as int? ?? 1,
      totalRows: map['total_rows'] as int? ?? 0,
    );
  }
}

