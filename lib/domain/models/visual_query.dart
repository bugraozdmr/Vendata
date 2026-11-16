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
  String type; // 'LEFT JOIN', 'INNER JOIN', 'RIGHT JOIN', 'FULL OUTER JOIN', 'CROSS JOIN'
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
    if (table.isEmpty) return '';
    final joinTableEsc = SqlSanitizer.escapeIdentifier(table);
    if (type == 'CROSS JOIN') return '$type $joinTableEsc';
    if (leftCol.isEmpty || rightCol.isEmpty) return '';
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

  VisualQuery copy() {
    return VisualQuery(
      selectedTable: selectedTable,
      isDistinct: isDistinct,
      selectedColumns: List<String>.from(selectedColumns),
      calculatedFields: calculatedFields
          .map((c) => CalculatedField(expression: c.expression, alias: c.alias))
          .toList(),
      filters: filters
          .map((f) => QueryFilter(
                column: f.column,
                operator: f.operator,
                value: f.value,
                combinator: f.combinator,
              ))
          .toList(),
      groupByColumns: List<String>.from(groupByColumns),
      aggregates: aggregates
          .map((a) => AggregateMetric(
                func: a.func,
                column: a.column,
                customAlias: a.customAlias,
              ))
          .toList(),
      havingClause: havingClause,
      orders: orders
          .map((o) => QueryOrder(column: o.column, ascending: o.ascending))
          .toList(),
      joinConfig: joinConfig != null
          ? JoinConfig(
              type: joinConfig!.type,
              table: joinConfig!.table,
              leftCol: joinConfig!.leftCol,
              rightCol: joinConfig!.rightCol,
            )
          : null,
      limit: limit,
      offset: offset,
    );
  }

  static VisualQuery? tryParseSql(String rawSql) {
    final sql = rawSql.trim();
    if (sql.isEmpty) return null;

    if (!RegExp(r'^\s*SELECT\b', caseSensitive: false).hasMatch(sql)) {
      return null;
    }

    try {
      // 1. Table name after FROM
      final fromMatch = RegExp(
        r'\bFROM\s+["`]?([a-zA-Z0-9_]+)["`]?(\.[a-zA-Z0-9_]+)?',
        caseSensitive: false,
      ).firstMatch(sql);

      if (fromMatch == null) return null;
      final table = fromMatch.group(1) ?? '';
      if (table.isEmpty) return null;

      final vq = VisualQuery(selectedTable: table);

      // 2. DISTINCT
      if (RegExp(r'\bSELECT\s+DISTINCT\b', caseSensitive: false).hasMatch(sql)) {
        vq.isDistinct = true;
      }

      // 3. Columns between SELECT and FROM
      final selectPartMatch = RegExp(
        r'^\s*SELECT\s+(?:DISTINCT\s+)?(.*?)\s+\bFROM\b',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(sql);

      if (selectPartMatch != null) {
        final colStr = selectPartMatch.group(1)?.trim() ?? '*';
        if (colStr != '*') {
          final cols = colStr.split(',').map((c) {
            var trimmed = c.trim();
            if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
                (trimmed.startsWith('`') && trimmed.endsWith('`'))) {
              trimmed = trimmed.substring(1, trimmed.length - 1);
            }
            return trimmed;
          }).where((c) => c.isNotEmpty && !c.contains('(')).toList();
          vq.selectedColumns = cols;
        }
      }

      // 4. WHERE clause
      final whereMatch = RegExp(
        r'\bWHERE\s+(.*?)(?:\s+\b(?:GROUP\s+BY|ORDER\s+BY|LIMIT)\b|\s*;|\s*$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(sql);

      if (whereMatch != null) {
        final whereClause = whereMatch.group(1)?.trim() ?? '';
        if (whereClause.isNotEmpty) {
          final conditions = _splitWhereConditions(whereClause);
          for (final cond in conditions) {
            final filter = _parseCondition(cond.condition, cond.combinator);
            if (filter != null) {
              vq.filters.add(filter);
            }
          }
        }
      }

      // 5. ORDER BY
      final orderMatch = RegExp(
        r'\bORDER\s+BY\s+(.*?)(?:\s+\bLIMIT\b|\s*;|\s*$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(sql);

      if (orderMatch != null) {
        final orderStr = orderMatch.group(1)?.trim() ?? '';
        final parts = orderStr.split(',');
        for (final p in parts) {
          final trimmed = p.trim();
          final isDesc = RegExp(r'\bDESC\b', caseSensitive: false).hasMatch(trimmed);
          var colName = trimmed.replaceAll(RegExp(r'\s+(ASC|DESC)\b', caseSensitive: false), '').trim();
          if ((colName.startsWith('"') && colName.endsWith('"')) ||
              (colName.startsWith('`') && colName.endsWith('`'))) {
            colName = colName.substring(1, colName.length - 1);
          }
          if (colName.isNotEmpty) {
            vq.orders.add(QueryOrder(column: colName, ascending: !isDesc));
          }
        }
      }

      // 6. LIMIT
      final limitMatch = RegExp(r'\bLIMIT\s+(\d+)', caseSensitive: false).firstMatch(sql);
      if (limitMatch != null) {
        vq.limit = int.tryParse(limitMatch.group(1)!) ?? 50;
      }

      // 7. OFFSET
      final offsetMatch = RegExp(r'\bOFFSET\s+(\d+)', caseSensitive: false).firstMatch(sql);
      if (offsetMatch != null) {
        vq.offset = int.tryParse(offsetMatch.group(1)!) ?? 0;
      }

      return vq;
    } catch (_) {
      return null;
    }
  }

  static QueryFilter? _parseCondition(String rawCond, String combinator) {
    final cond = rawCond.trim();
    if (cond.isEmpty) return null;

    final isNotNullMatch = RegExp(r'["`]?([a-zA-Z0-9_]+)["`]?\s+IS\s+NOT\s+NULL', caseSensitive: false).firstMatch(cond);
    if (isNotNullMatch != null) {
      return QueryFilter(column: isNotNullMatch.group(1)!, operator: 'IS NOT NULL', value: '', combinator: combinator);
    }

    final isNullMatch = RegExp(r'["`]?([a-zA-Z0-9_]+)["`]?\s+IS\s+NULL', caseSensitive: false).firstMatch(cond);
    if (isNullMatch != null) {
      return QueryFilter(column: isNullMatch.group(1)!, operator: 'IS NULL', value: '', combinator: combinator);
    }

    final likeMatch = RegExp(r'["`]?([a-zA-Z0-9_]+)["`]?\s+(NOT\s+LIKE|LIKE)\s+(.*)', caseSensitive: false).firstMatch(cond);
    if (likeMatch != null) {
      final col = likeMatch.group(1)!;
      final op = likeMatch.group(2)!.toUpperCase();
      var val = likeMatch.group(3)!.trim();
      if (val.startsWith("'") && val.endsWith("'")) val = val.substring(1, val.length - 1);
      if (val.startsWith('%') && val.endsWith('%')) {
        return QueryFilter(column: col, operator: 'LIKE', value: val.substring(1, val.length - 1), combinator: combinator);
      } else if (val.endsWith('%')) {
        return QueryFilter(column: col, operator: 'STARTS WITH', value: val.substring(0, val.length - 1), combinator: combinator);
      } else if (val.startsWith('%')) {
        return QueryFilter(column: col, operator: 'ENDS WITH', value: val.substring(1), combinator: combinator);
      }
      return QueryFilter(column: col, operator: op, value: val, combinator: combinator);
    }

    final compMatch = RegExp(r'["`]?([a-zA-Z0-9_]+)["`]?\s*(=|!=|<>|>=|<=|>|<)\s*(.*)', caseSensitive: false).firstMatch(cond);
    if (compMatch != null) {
      final col = compMatch.group(1)!;
      var op = compMatch.group(2)!;
      if (op == '<>') op = '!=';
      var val = compMatch.group(3)!.trim();
      if (val.startsWith("'") && val.endsWith("'")) val = val.substring(1, val.length - 1);
      return QueryFilter(column: col, operator: op, value: val, combinator: combinator);
    }

    return null;
  }

  static List<({String condition, String combinator})> _splitWhereConditions(String whereStr) {
    final result = <({String condition, String combinator})>[];
    final tokens = whereStr.split(RegExp(r'\s+\b(AND|OR)\b\s+', caseSensitive: false));
    final combinators = RegExp(r'\s+\b(AND|OR)\b\s+', caseSensitive: false)
        .allMatches(whereStr)
        .map((m) => m.group(1)!.toUpperCase())
        .toList();

    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i].trim();
      if (t.isNotEmpty) {
        final comb = i == 0 ? 'AND' : (i - 1 < combinators.length ? combinators[i - 1] : 'AND');
        result.add((condition: t, combinator: comb));
      }
    }
    return result;
  }
}
