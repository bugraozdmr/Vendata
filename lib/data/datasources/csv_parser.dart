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
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }

    final rawRows = Csv(
      autoDetect: true,
      dynamicTyping: true,
      skipEmptyLines: true,
    ).decode(text);

    if (rawRows.isEmpty) {
      return ParsedDataset(name: defaultName, headers: [], rows: []);
    }

    final headers = rawRows.first.map((e) => e?.toString() ?? '').toList();
    final dataRows = rawRows.skip(1).where((row) => row.any((cell) => cell != null && cell.toString().trim().isNotEmpty)).toList();

    return ParsedDataset(
      name: defaultName,
      headers: headers,
      rows: dataRows,
    );
  }
}
