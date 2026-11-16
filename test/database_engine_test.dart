import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendata/data/datasources/csv_parser.dart';
import 'package:vendata/data/services/database_engine.dart';

void main() {
  group('DatabaseEngine & CsvParser Tests', () {
    late DatabaseEngine engine;

    setUp(() {
      engine = DatabaseEngine();
    });

    tearDown(() {
      engine.close();
    });

    test('CSV parsing and table creation with numeric inference', () {
      const csvContent = '''urun,kategori,fiyat,stok
Laptop,Elektronik,45000,10
Telefon,Elektronik,32000,25
Masa,Mobilya,4500.5,5
''';
      final bytes = utf8.encode(csvContent);
      final dataset = CsvParser.parse(bytes: bytes, defaultName: 'envanter');

      expect(dataset.name, 'envanter');
      expect(dataset.headers, ['urun', 'kategori', 'fiyat', 'stok']);
      expect(dataset.rows.length, 3);

      engine.importDataset(dataset);

      final tables = engine.getTables();
      expect(tables.length, 1);
      expect(tables.first.name, 'envanter');
      expect(tables.first.rowCount, 3);

      final queryResult = engine.executeQuery(
        'SELECT kategori, SUM(fiyat * stok) as toplam_deger FROM envanter GROUP BY kategori ORDER BY toplam_deger DESC;',
      );

      expect(queryResult.hasError, false);
      expect(queryResult.columns, ['kategori', 'toplam_deger']);
      expect(queryResult.rows.length, 2);
      expect(queryResult.rows.first[0], 'Elektronik');
    });

    test('Multi-table JOIN query', () {
      final orders = ParsedDataset(
        name: 'orders',
        headers: ['order_id', 'cust_id', 'amount'],
        rows: [
          [101, 1, 500.0],
          [102, 2, 750.0],
          [103, 1, 250.0],
        ],
      );

      final customers = ParsedDataset(
        name: 'customers',
        headers: ['cust_id', 'name'],
        rows: [
          [1, 'Alice'],
          [2, 'Bob'],
        ],
      );

      engine.importDataset(orders);
      engine.importDataset(customers);

      final result = engine.executeQuery(
        'SELECT c.name, SUM(o.amount) AS total FROM customers c JOIN orders o ON c.cust_id = o.cust_id GROUP BY c.name ORDER BY total DESC, c.name ASC;',
      );

      expect(result.hasError, false);
      expect(result.rows.length, 2);
      expect(result.rows.first[0], 'Alice');
      expect(result.rows.first[1], 750.0);
    });

    test('Saved queries persistence, starring and table filtering in SQLite', () {
      final dataset = ParsedDataset(
        name: 'satislar',
        headers: ['id', 'tutar'],
        rows: [
          [1, 100],
          [2, 200],
        ],
      );
      engine.importDataset(dataset);

      // Execute query with table name
      engine.executeQuery('SELECT * FROM satislar;', tableName: 'satislar');

      final queries = engine.getSavedQueries();
      expect(queries.isNotEmpty, true);
      final firstQuery = queries.first;
      expect(firstQuery.queryText, 'SELECT * FROM satislar;');
      expect(firstQuery.tableName, 'satislar');
      expect(firstQuery.isFavorite, false);

      // Toggle favorite
      engine.toggleQueryFavorite(firstQuery.id);
      final starredQueries = engine.getSavedQueries(onlyFavorites: true);
      expect(starredQueries.length, 1);
      expect(starredQueries.first.id, firstQuery.id);
      expect(starredQueries.first.isFavorite, true);

      // Toggle off
      engine.toggleQueryFavorite(firstQuery.id);
      expect(engine.getSavedQueries(onlyFavorites: true).isEmpty, true);

      // Star by SQL (uniform state across duplicate history rows)
      expect(engine.isQueryFavorite('SELECT * FROM satislar;'), false);
      engine.setQueryFavoriteBySql('SELECT * FROM satislar;', favorite: true);
      expect(engine.isQueryFavorite('SELECT * FROM satislar;'), true);
      expect(engine.getSavedQueries(onlyFavorites: true).length, 1);
      engine.setQueryFavoriteBySql('SELECT * FROM satislar;', favorite: false);
      expect(engine.isQueryFavorite('SELECT * FROM satislar;'), false);

      // A query that has not been executed yet can be starred
      const unrun = 'SELECT 42 AS cevap;';
      expect(engine.isQueryFavorite(unrun), false);
      engine.setQueryFavoriteBySql(unrun, favorite: true);
      expect(engine.isQueryFavorite(unrun), true);
      expect(engine.getFavoriteSqls().contains(unrun), true);

      // Table specific filtering
      final tableQueries = engine.getSavedQueries(tableName: 'satislar');
      expect(tableQueries.length, 1);
      final otherTableQueries = engine.getSavedQueries(tableName: 'olmayan_tablo');
      expect(otherTableQueries.isEmpty, true);
    });
  });
}
