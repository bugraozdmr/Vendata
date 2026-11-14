import '../../core/utils/sql_sanitizer.dart';

enum AggregateFunc { count, sum, avg, min, max }

class QueryFilter {
  String column;
  String operator; // '=', '!=', '>', '<', '>=', '<=', 'LIKE', 'STARTS WITH', 'ENDS WITH', 'IS NULL', 'IS NOT NULL'
  String value;
  String combinator; // 'AND', 'OR'

  QueryFilter({
    required this.column,
    this.operator = '=',
    this.value = '',
    this.combinator = 'AND',
  });

  String toSqlCondition() {
    final colEsc = SqlSanitizer.escapeIdentifier(column);
    final val = value.trim();

    switch (operator) {
      case 'IS NULL':
        return '$colEsc IS NULL';
      case 'IS NOT NULL':
        return '$colEsc IS NOT NULL';
      case 'LIKE':
        final sanitized = val.replaceAll("'", "''");
        return "$colEsc LIKE '%$sanitized%'";
      case 'STARTS WITH':
        final sanitized = val.replaceAll("'", "''");
        return "$colEsc LIKE '$sanitized%'";
      case 'ENDS WITH':
        final sanitized = val.replaceAll("'", "''");
        return "$colEsc LIKE '%$sanitized'";
      case 'NOT LIKE':
        final sanitized = val.replaceAll("'", "''");
        return "$colEsc NOT LIKE '%$sanitized%'";
      default:
        final numVal = num.tryParse(val);
        if (numVal != null) {
          return '$colEsc $operator $numVal';
        } else {
          final sanitized = val.replaceAll("'", "''");
          return "$colEsc $operator '$sanitized'";
        }
    }
  }
}

class QueryOrder {
  String column;
  bool ascending;

  QueryOrder({
    required this.column,
    this.ascending = true,
  });

  String toSql() {
    final colEsc = SqlSanitizer.escapeIdentifier(column);
    return '$colEsc ${ascending ? 'ASC' : 'DESC'}';
  }
}

class AggregateMetric {
  AggregateFunc func;
  String? column;
  String? customAlias;

  AggregateMetric({
    required this.func,
    this.column,
    this.customAlias,
  });

  String toSql() {
    final fn = func.name.toUpperCase();
    if (fn == 'COUNT' && (column == null || column!.isEmpty || column == '*')) {
      final alias = customAlias?.isNotEmpty == true ? customAlias! : 'toplam_kayit';
      return 'COUNT(*) AS ${SqlSanitizer.escapeIdentifier(alias)}';
    }
    final targetCol = column?.isNotEmpty == true ? column! : '*';
    final colEsc = targetCol == '*' ? '*' : SqlSanitizer.escapeIdentifier(targetCol);
    final defaultAlias = '${func.name}_$targetCol';
    final alias = customAlias?.isNotEmpty == true ? customAlias! : defaultAlias;
    return '$fn($colEsc) AS ${SqlSanitizer.escapeIdentifier(alias)}';
  }
}

class CalculatedField {
  String expression;
  String alias;

  CalculatedField({
    required this.expression,
    required this.alias,
  });

  String toSql() {
    final cleanAlias = SqlSanitizer.sanitizeColumnName(alias.isNotEmpty ? alias : 'hesaplanan');
    return '($expression) AS ${SqlSanitizer.escapeIdentifier(cleanAlias)}';
  }
}

class JoinConfig {
  String type; // 'LEFT JOIN', 'INNER JOIN'
  String table;
  String leftCol;
  String rightCol;

  JoinConfig({
    this.type = 'LEFT JOIN',
    required this.table,
    required this.leftCol,
    required this.rightCol,
  });

  String toSql(String primaryTable) {
    if (table.isEmpty || leftCol.isEmpty || rightCol.isEmpty) return '';
    final joinTableEsc = SqlSanitizer.escapeIdentifier(table);
    final leftEsc = '${SqlSanitizer.escapeIdentifier(primaryTable)}.${SqlSanitizer.escapeIdentifier(leftCol)}';
    final rightEsc = '$joinTableEsc.${SqlSanitizer.escapeIdentifier(rightCol)}';
    return '$type $joinTableEsc ON $leftEsc = $rightEsc';
  }
}

class VisualQuery {
  String selectedTable;
  bool isDistinct;
  List<String> selectedColumns;
  List<CalculatedField> calculatedFields;
  List<QueryFilter> filters;
  List<String> groupByColumns;
  List<AggregateMetric> aggregates;
  String? havingClause;
  List<QueryOrder> orders;
  JoinConfig? joinConfig;
  int limit;
  int offset;

  VisualQuery({
    required this.selectedTable,
    this.isDistinct = false,
    this.selectedColumns = const [],
    List<CalculatedField>? calculatedFields,
    List<QueryFilter>? filters,
    this.groupByColumns = const [],
    List<AggregateMetric>? aggregates,
    this.havingClause,
    List<QueryOrder>? orders,
    this.joinConfig,
    this.limit = 50,
    this.offset = 0,
  })  : calculatedFields = calculatedFields ?? [],
        filters = filters ?? [],
        aggregates = aggregates ?? [],
        orders = orders ?? [];

  String toSql() {
    if (selectedTable.isEmpty) return '';

    final tableEsc = SqlSanitizer.escapeIdentifier(selectedTable);
    final selectParts = <String>[];

    // 1. Projection (Sütunlar)
    if (selectedColumns.isEmpty && aggregates.isEmpty && calculatedFields.isEmpty) {
      selectParts.add('*');
    } else {
      for (final col in selectedColumns) {
        selectParts.add(SqlSanitizer.escapeIdentifier(col));
      }
    }

    // 2. Calculated fields (Hesaplanmış sütunlar)
    for (final calc in calculatedFields) {
      if (calc.expression.trim().isNotEmpty) {
        selectParts.add(calc.toSql());
      }
    }

    // 3. Aggregates (Agregasyonlar)
    for (final agg in aggregates) {
      selectParts.add(agg.toSql());
    }

    final distinctKeyword = isDistinct ? 'DISTINCT ' : '';
    final selectClause = selectParts.isEmpty ? '*' : selectParts.join(', ');
    var sql = 'SELECT $distinctKeyword$selectClause FROM $tableEsc';

    // 4. JOIN
    if (joinConfig != null) {
      final joinSql = joinConfig!.toSql(selectedTable);
      if (joinSql.isNotEmpty) {
        sql += ' $joinSql';
      }
    }

    // 5. WHERE filters
    if (filters.isNotEmpty) {
      final filterClauses = <String>[];
      for (var i = 0; i < filters.length; i++) {
        final f = filters[i];
        final cond = f.toSqlCondition();
        if (i == 0) {
          filterClauses.add(cond);
        } else {
          filterClauses.add('${f.combinator} $cond');
        }
      }
      sql += ' WHERE ${filterClauses.join(' ')}';
    }

    // 6. GROUP BY
    if (groupByColumns.isNotEmpty) {
      final groupEsc = groupByColumns.map((c) => SqlSanitizer.escapeIdentifier(c)).join(', ');
      sql += ' GROUP BY $groupEsc';
    }

    // 7. HAVING
    if (havingClause != null && havingClause!.trim().isNotEmpty) {
      sql += ' HAVING ${havingClause!.trim()}';
    }

    // 8. ORDER BY
    if (orders.isNotEmpty) {
      final orderEsc = orders.map((o) => o.toSql()).join(', ');
      sql += ' ORDER BY $orderEsc';
    }

    // 9. LIMIT & OFFSET
    if (limit > 0) {
      sql += ' LIMIT $limit';
      if (offset > 0) {
        sql += ' OFFSET $offset';
      }
    }
    sql += ';';

    return sql;
  }
}
