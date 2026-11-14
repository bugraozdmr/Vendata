import 'package:flutter_test/flutter_test.dart';
import 'package:vendata/domain/models/visual_query.dart';

void main() {
  group('VisualQuery Builder Advanced Tests', () {
    test('Default query produces SELECT * FROM table LIMIT 50', () {
      final q = VisualQuery(selectedTable: 'siparisler');
      expect(q.toSql(), 'SELECT * FROM "siparisler" LIMIT 50;');
    });

    test('Aggregate with GROUP BY, HAVING and ORDER BY', () {
      final q = VisualQuery(
        selectedTable: 'satislar',
        selectedColumns: ['kategori'],
        aggregates: [
          AggregateMetric(func: AggregateFunc.sum, column: 'fiyat', customAlias: 'toplam_ciro'),
          AggregateMetric(func: AggregateFunc.count, column: '*', customAlias: 'adet'),
        ],
        groupByColumns: ['kategori'],
        havingClause: 'SUM("fiyat") > 5000',
        orders: [
          QueryOrder(column: 'toplam_ciro', ascending: false),
        ],
        limit: 20,
      );

      final sql = q.toSql();
      expect(sql.contains('SELECT "kategori", SUM("fiyat") AS "toplam_ciro", COUNT(*) AS "adet" FROM "satislar"'), true);
      expect(sql.contains('GROUP BY "kategori"'), true);
      expect(sql.contains('HAVING SUM("fiyat") > 5000'), true);
      expect(sql.contains('ORDER BY "toplam_ciro" DESC'), true);
      expect(sql.contains('LIMIT 20;'), true);
    });

    test('Multiple WHERE filters with AND/OR and LIKE', () {
      final q = VisualQuery(
        selectedTable: 'musteriler',
        isDistinct: true,
        selectedColumns: ['isim', 'sehir'],
        filters: [
          QueryFilter(column: 'sehir', operator: '=', value: 'Ankara'),
          QueryFilter(column: 'isim', operator: 'LIKE', value: 'Ahmet', combinator: 'AND'),
          QueryFilter(column: 'email', operator: 'IS NOT NULL', combinator: 'AND'),
        ],
        orders: [
          QueryOrder(column: 'isim', ascending: true),
        ],
        limit: 10,
        offset: 20,
      );

      final sql = q.toSql();
      expect(sql.contains('SELECT DISTINCT "isim", "sehir" FROM "musteriler"'), true);
      expect(sql.contains("WHERE \"sehir\" = 'Ankara' AND \"isim\" LIKE '%Ahmet%' AND \"email\" IS NOT NULL"), true);
      expect(sql.contains('ORDER BY "isim" ASC'), true);
      expect(sql.contains('LIMIT 10 OFFSET 20;'), true);
    });

    test('Calculated expressions and JOIN', () {
      final q = VisualQuery(
        selectedTable: 'orders',
        selectedColumns: ['id'],
        calculatedFields: [
          CalculatedField(expression: 'fiyat * 1.20', alias: 'kdvli_fiyat'),
          CalculatedField(expression: "strftime('%Y', tarih)", alias: 'siparis_yili'),
        ],
        joinConfig: JoinConfig(
          type: 'LEFT JOIN',
          table: 'customers',
          leftCol: 'customer_id',
          rightCol: 'id',
        ),
      );

      final sql = q.toSql();
      expect(sql.contains('LEFT JOIN "customers" ON "orders"."customer_id" = "customers"."id"'), true);
      expect(sql.contains('(fiyat * 1.20) AS "kdvli_fiyat"'), true);
      expect(sql.contains("(strftime('%Y', tarih)) AS \"siparis_yili\""), true);
    });
  });
}
