enum SupportedFileType { excel, csv, sql, unknown }

class FileHelper {
  FileHelper._();

  static SupportedFileType getFileType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return SupportedFileType.excel;
    }
    if (lower.endsWith('.csv') || lower.endsWith('.tsv')) {
      return SupportedFileType.csv;
    }
    if (lower.endsWith('.sql') || lower.endsWith('.sqlite') || lower.endsWith('.db')) {
      return SupportedFileType.sql;
    }
    return SupportedFileType.unknown;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

