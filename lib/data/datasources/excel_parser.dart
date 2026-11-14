import 'package:excel/excel.dart';
import 'csv_parser.dart';

class ExcelParser {
  ExcelParser._();

  static List<ParsedDataset> parse({
    required List<int> bytes,
    required String fileBaseName,
  }) {
    final excel = Excel.decodeBytes(bytes);
    final datasets = <ParsedDataset>[];

    for (final tableKey in excel.tables.keys) {
      final sheet = excel.tables[tableKey];
      if (sheet == null || sheet.rows.isEmpty) continue;

      final rows = sheet.rows;
      if (rows.isEmpty) continue;

      final headerRow = rows.first;
      final headers = headerRow.map((cell) {
        final v = cell?.value;
        return v != null ? v.toString().trim() : '';
      }).toList();

      final dataRows = <List<dynamic>>[];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final rowData = row.map((cell) {
          final val = cell?.value;
          if (val == null) return null;
          if (val is TextCellValue) return val.value.text;
          if (val is IntCellValue) return val.value;
          if (val is DoubleCellValue) return val.value;
          if (val is BoolCellValue) return val.value;
          return val.toString();
        }).toList();

        if (rowData.any((c) => c != null && c.toString().trim().isNotEmpty)) {
          dataRows.add(rowData);
        }
      }

      if (headers.any((h) => h.isNotEmpty)) {
        final tableName = excel.tables.keys.length == 1
            ? fileBaseName
            : '${fileBaseName}_$tableKey';
        datasets.add(
          ParsedDataset(
            name: tableName,
            headers: headers,
            rows: dataRows,
          ),
        );
      }
    }

    return datasets;
  }
}

