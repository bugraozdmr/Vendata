class SqlSanitizer {
  SqlSanitizer._();

  static String sanitizeTableName(String name) {
    var clean = name.trim().replaceAll(RegExp(r'[^\w\d_]'), '_');
    if (clean.isEmpty) {
      clean = 'dataset';
    }
    if (RegExp(r'^\d').hasMatch(clean)) {
      clean = 't_$clean';
    }
    return clean.toLowerCase();
  }

  static String sanitizeColumnName(String name) {
    var clean = name.trim().replaceAll(RegExp(r'[^\w\d_]'), '_');
    if (clean.isEmpty) clean = 'col';
    if (RegExp(r'^\d').hasMatch(clean)) clean = 'c_$clean';
    return clean.toLowerCase();
  }

  static List<String> sanitizeColumnNames(List<String> rawHeaders) {
    final seen = <String, int>{};
    final sanitized = <String>[];

    for (var i = 0; i < rawHeaders.length; i++) {
      var header = rawHeaders[i].trim();
      if (header.isEmpty) {
        header = 'col_${i + 1}';
      }
      header = header.replaceAll(RegExp(r'[^\w\d_]'), '_');
      if (RegExp(r'^\d').hasMatch(header)) {
        header = 'c_$header';
      }
      header = header.toLowerCase();

      final count = seen[header] ?? 0;
      seen[header] = count + 1;

      if (count > 0) {
        sanitized.add('${header}_$count');
      } else {
        sanitized.add(header);
      }
    }
    return sanitized;
  }

  static String escapeIdentifier(String name) {
    return '"${name.replaceAll('"', '""')}"';
  }
}

