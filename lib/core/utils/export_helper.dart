import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/query_result.dart';

class ExportHelper {
  ExportHelper._();

  static Future<void> shareAsCsv(QueryResult result, {String baseName = 'query_result'}) async {
    final rows = <List<dynamic>>[];
    rows.add(result.columns);
    rows.addAll(result.rows);

    final csvData = Csv().encode(rows);
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(filePath);
    await file.writeAsString(csvData);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        text: 'Exported CSV Data',
      ),
    );
  }

  static Future<void> shareAsExcel(QueryResult result, {String baseName = 'query_result'}) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[defaultSheet];

    final headerRow = result.columns.map((c) => TextCellValue(c)).toList();
    sheet.appendRow(headerRow);

    for (final row in result.rows) {
      final cellRow = row.map<CellValue?>((val) {
        if (val == null) return null;
        if (val is int) return IntCellValue(val);
        if (val is double) return DoubleCellValue(val);
        if (val is bool) return BoolCellValue(val);
        return TextCellValue(val.toString());
      }).toList();
      sheet.appendRow(cellRow);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        text: 'Exported Excel Data',
      ),
    );
  }
}
