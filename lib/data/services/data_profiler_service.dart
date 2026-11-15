import '../../core/utils/sql_sanitizer.dart';
import '../../domain/models/table_schema.dart';
import 'db_session.dart';

class ColumnProfile {
  final String name;
  final String type;
  final int totalRows;
  final int nullCount;
  final int distinctCount;

  const ColumnProfile({
    required this.name,
    required this.type,
    required this.totalRows,
    required this.nullCount,
    required this.distinctCount,
  });

  double get nullPercentage => totalRows > 0 ? (nullCount / totalRows) * 100 : 0.0;
  bool get hasMissingData => nullCount > 0;
}

class TableProfile {
  final String tableName;
  final int totalRows;
  final int columnCount;
  final List<ColumnProfile> columns;
  final int duplicateCount;

  const TableProfile({
    required this.tableName,
    required this.totalRows,
    required this.columnCount,
    required this.columns,
    required this.duplicateCount,
  });
}

class DataProfilerService {
  final DbSession _session;

  DataProfilerService(this._session);

  DbSession get session => _session;

  Future<List<String>> getDistinctColumnValues(String tableName, String colName, {int limit = 8}) async {
    try {
      final colEsc = SqlSanitizer.escapeIdentifier(colName);
      final tableEsc = SqlSanitizer.escapeIdentifier(tableName);
      final sql = 'SELECT DISTINCT $colEsc FROM $tableEsc WHERE $colEsc IS NOT NULL LIMIT $limit;';
      final res = await _session.execute(sql);
      return res.rows.map((r) => r.first?.toString() ?? 'Bilinmeyen').toList();
    } catch (_) {
      return [];
    }
  }

  Future<TableProfile> profileTable(TableSchema schema) async {
    final tableName = schema.name;
    final totalRows = schema.rowCount;
    final columnProfiles = <ColumnProfile>[];

    for (final col in schema.columns) {
      final colEsc = SqlSanitizer.escapeIdentifier(col.name);
      final tableEsc = SqlSanitizer.escapeIdentifier(tableName);

      int nullCount = 0;
      int distinctCount = 0;

      try {
        final query = 'SELECT ($totalRows - COUNT($colEsc)) AS null_cnt, COUNT(DISTINCT $colEsc) AS dist_cnt FROM $tableEsc;';
        final res = await _session.execute(query);
        if (res.rows.isNotEmpty) {
          final row = res.rows.first;
          nullCount = (row[0] as num?)?.toInt() ?? 0;
          distinctCount = (row[1] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      columnProfiles.add(
        ColumnProfile(
          name: col.name,
          type: col.type,
          totalRows: totalRows,
          nullCount: nullCount,
          distinctCount: distinctCount,
        ),
      );
    }

    // Check duplicate rows
    int duplicateCount = 0;
    try {
      final colsEsc = schema.columnNames.map((c) => SqlSanitizer.escapeIdentifier(c)).join(', ');
      final dupQuery = '''
        SELECT COUNT(*) as dup_cnt FROM (
          SELECT $colsEsc, COUNT(*) as cnt 
          FROM ${SqlSanitizer.escapeIdentifier(tableName)} 
          GROUP BY $colsEsc 
          HAVING cnt > 1
        );
      ''';
      final dupRes = await _session.execute(dupQuery);
      if (dupRes.rows.isNotEmpty) {
        duplicateCount = (dupRes.rows.first[0] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    return TableProfile(
      tableName: tableName,
      totalRows: totalRows,
      columnCount: schema.columns.length,
      columns: columnProfiles,
      duplicateCount: duplicateCount,
    );
  }

  String generateDuplicatesSql(TableSchema schema) {
    final colsEsc = schema.columnNames.map((c) => SqlSanitizer.escapeIdentifier(c)).join(', ');
    final tableEsc = SqlSanitizer.escapeIdentifier(schema.name);
    return '''
SELECT $colsEsc, COUNT(*) AS tekrar_sayisi 
FROM $tableEsc 
GROUP BY $colsEsc 
HAVING COUNT(*) > 1 
ORDER BY tekrar_sayisi DESC;
'''.trim();
  }

  String generateMissingDataSql(TableSchema schema) {
    final tableEsc = SqlSanitizer.escapeIdentifier(schema.name);
    final conditions = schema.columnNames
        .map((c) => '${SqlSanitizer.escapeIdentifier(c)} IS NULL')
        .join(' OR ');
    return 'SELECT * FROM $tableEsc WHERE $conditions LIMIT 100;';
  }

  String generateNumericSummarySql(TableSchema schema) {
    final numericCols = schema.columns
        .where((c) => c.type == 'INTEGER' || c.type == 'REAL')
        .map((c) => c.name)
        .toList();

    if (numericCols.isEmpty) {
      return 'SELECT * FROM ${SqlSanitizer.escapeIdentifier(schema.name)} LIMIT 50;';
    }

    final tableEsc = SqlSanitizer.escapeIdentifier(schema.name);
    final selectParts = <String>[];
    for (final col in numericCols) {
      final colEsc = SqlSanitizer.escapeIdentifier(col);
      selectParts.add('MIN($colEsc) AS ${col}_min');
      selectParts.add('MAX($colEsc) AS ${col}_max');
      selectParts.add('ROUND(AVG($colEsc), 2) AS ${col}_ortalama');
      selectParts.add('ROUND(SUM($colEsc), 2) AS ${col}_toplam');
    }

    return 'SELECT ${selectParts.join(',\n       ')} \nFROM $tableEsc;';
  }

  String generatePivotSql({
    required String tableName,
    required String rowColumn,
    required String pivotColumn,
    required String valueColumn,
    required List<String> distinctPivotValues,
    String aggFunction = 'SUM',
  }) {
    final tableEsc = SqlSanitizer.escapeIdentifier(tableName);
    final rowEsc = SqlSanitizer.escapeIdentifier(rowColumn);
    final valEsc = SqlSanitizer.escapeIdentifier(valueColumn);
    final pivotEsc = SqlSanitizer.escapeIdentifier(pivotColumn);

    final pivotCases = distinctPivotValues.map((val) {
      final sanitizedVal = val.replaceAll("'", "''");
      final aliasEsc = SqlSanitizer.escapeIdentifier(val);
      return '$aggFunction(CASE WHEN $pivotEsc = \'$sanitizedVal\' THEN $valEsc ELSE 0 END) AS $aliasEsc';
    }).join(',\n       ');

    return '''
SELECT $rowEsc,
       $pivotCases
FROM $tableEsc
GROUP BY $rowEsc
ORDER BY $rowEsc ASC;
'''.trim();
  }
}
