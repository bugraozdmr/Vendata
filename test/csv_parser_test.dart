import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendata/data/datasources/csv_parser.dart';

void main() {
  group('CsvParser Tests', () {
    test('parses comma-separated values', () {
      final csv = 'id,name,score\n1,Alice,95.5\n2,Bob,88.0';
      final dataset = CsvParser.parse(
        bytes: utf8.encode(csv),
        defaultName: 'students',
      );
      expect(dataset.headers, ['id', 'name', 'score']);
      expect(dataset.rows.length, 2);
      expect(dataset.rows[0], [1, 'Alice', 95.5]);
    });

    test('parses semicolon-separated values with commas in decimals', () {
      final csv = 'Urun;Fiyat;Adet\nElma;12,50;10\nArmut;20,00;5';
      final dataset = CsvParser.parse(
        bytes: utf8.encode(csv),
        defaultName: 'market',
      );
      expect(dataset.headers, ['Urun', 'Fiyat', 'Adet']);
      expect(dataset.rows.length, 2);
    });

    test('parses tab-separated values (TSV)', () {
      final tsv = 'colA\tcolB\tcolC\nval1\tval2\tval3';
      final dataset = CsvParser.parse(
        bytes: utf8.encode(tsv),
        defaultName: 'tsv_test',
      );
      expect(dataset.headers, ['colA', 'colB', 'colC']);
      expect(dataset.rows.length, 1);
    });

    test('parses pipe-separated values', () {
      final pipe = 'A|B|C\n1|2|3';
      final dataset = CsvParser.parse(
        bytes: utf8.encode(pipe),
        defaultName: 'pipe_test',
      );
      expect(dataset.headers, ['A', 'B', 'C']);
      expect(dataset.rows.length, 1);
    });

    test('handles UTF-8 with BOM correctly', () {
      final bomCsv = [0xEF, 0xBB, 0xBF, ...utf8.encode('id,name\n1,Test')];
      final dataset = CsvParser.parse(
        bytes: bomCsv,
        defaultName: 'bom_test',
      );
      expect(dataset.headers, ['id', 'name']);
      expect(dataset.rows.length, 1);
    });
  });
}

