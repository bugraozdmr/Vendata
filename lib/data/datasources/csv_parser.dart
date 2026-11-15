import 'dart:convert';
import 'package:csv/csv.dart';

class ParsedDataset {
  final String name;
  final List<String> headers;
  final List<List<dynamic>> rows;

  const ParsedDataset({
    required this.name,
    required this.headers,
    required this.rows,
  });
}

class CsvParser {
  CsvParser._();

  static ParsedDataset parse({
    required List<int> bytes,
    required String defaultName,
  }) {
    // 1. Strip UTF-8 BOM if present
    var data = bytes;
    if (data.length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF) {
      data = data.sublist(3);
    }

    // 2. Decode text (try UTF-8, then fallback to Latin-1)
    String text;
    try {
      text = utf8.decode(data);
    } catch (_) {
      text = latin1.decode(data);
    }

    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    return parseString(text: text, defaultName: defaultName);
  }

  static ParsedDataset parseString({
    required String text,
    required String defaultName,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return ParsedDataset(name: defaultName, headers: [], rows: []);
    }

    // 3. Delimiter detection
    final delimiter = detectDelimiter(trimmed);

    // 4. Decode with detected delimiter
    var rawRows = _decodeWithDelimiter(trimmed, delimiter);

    // Fallback: If only 1 column was produced, try other standard delimiters
    if (rawRows.isNotEmpty && rawRows.first.length <= 1) {
      const candidates = [',', ';', '\t', '|'];
      for (final alt in candidates) {
        if (alt == delimiter) continue;
        final altRows = _decodeWithDelimiter(trimmed, alt);
        if (altRows.isNotEmpty && altRows.first.length > 1) {
          rawRows = altRows;
          break;
        }
      }
    }

    if (rawRows.isEmpty) {
      return ParsedDataset(name: defaultName, headers: [], rows: []);
    }

    final rawHeaders = rawRows.first;
    final headers = <String>[];
    for (var i = 0; i < rawHeaders.length; i++) {
      final h = rawHeaders[i]?.toString().trim() ?? '';
      headers.add(h.isNotEmpty ? h : 'col_${i + 1}');
    }

    final dataRows = rawRows
        .skip(1)
        .where((row) => row.any((cell) => cell != null && cell.toString().trim().isNotEmpty))
        .map((row) {
          // Ensure all rows match the header length
          if (row.length < headers.length) {
            return List<dynamic>.from(row)..addAll(List.filled(headers.length - row.length, null));
          } else if (row.length > headers.length) {
            return row.sublist(0, headers.length);
          }
          return row;
        })
        .toList();

    return ParsedDataset(
      name: defaultName,
      headers: headers,
      rows: dataRows,
    );
  }

  static List<List<dynamic>> _decodeWithDelimiter(String text, String delimiter) {
    try {
      return Csv(
        fieldDelimiter: delimiter,
        dynamicTyping: true,
        skipEmptyLines: true,
      ).decode(text);
    } catch (_) {
      try {
        return Csv(
          autoDetect: true,
          dynamicTyping: true,
          skipEmptyLines: true,
        ).decode(text);
      } catch (_) {
        return [];
      }
    }
  }

  static String detectDelimiter(String text) {
    final lines = text.split(RegExp(r'\r\n|\r|\n')).where((l) => l.trim().isNotEmpty).take(40).toList();
    if (lines.isEmpty) return ',';

    // Support explicit Excel 'sep=;' or 'sep=,' header
    final firstLine = lines.first.trim();
    final sepMatch = RegExp(r'^sep=([,;\t|])', caseSensitive: false).firstMatch(firstLine);
    if (sepMatch != null) {
      return sepMatch.group(1)!;
    }

    const candidates = [',', ';', '\t', '|'];
    String bestDelimiter = ',';
    int maxCols = 1;
    int maxScore = -1;

    for (final delim in candidates) {
      final counts = <int>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        counts.add(delim.allMatches(line).length);
      }

      if (counts.isEmpty) continue;

      final firstCount = counts.first;
      if (firstCount == 0) continue;

      // Consistency: How many lines have the same count of this delimiter?
      final matchesCount = counts.where((c) => c == firstCount).length;
      final consistencyRatio = matchesCount / counts.length;

      // Score prioritizes matching multiple columns with high line-to-line consistency
      final score = (firstCount * 10) + (consistencyRatio * 25).round();

      if (firstCount > 0 && (score > maxScore || (score == maxScore && firstCount > maxCols))) {
        maxScore = score;
        maxCols = firstCount;
        bestDelimiter = delim;
      }
    }

    return bestDelimiter;
  }
}
