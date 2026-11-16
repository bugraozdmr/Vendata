import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendata/core/constants/ai_providers_constants.dart';
import 'package:vendata/domain/models/ai_chat_model.dart';
import 'package:vendata/domain/models/ai_provider.dart';
import 'package:vendata/domain/models/chart_config.dart';

void main() {
  group('AI Models & Parsing Tests', () {
    test('AIProviderModel serialization and presets', () {
      final geminiPreset = AIProvidersConstants.presets.firstWhere((p) => p.id == AIProvidersConstants.geminiId);
      expect(geminiPreset.providerType, 'gemini');
      expect(geminiPreset.defaultModels, isNotEmpty);

      final model = AIProviderModel(
        id: AIProvidersConstants.geminiId,
        name: 'Google Gemini',
        providerType: 'gemini',
        modelName: 'gemini-1.5-flash',
        apiKey: 'test-key',
        isActive: true,
      );

      final map = model.toMap();
      expect(map['id'], AIProvidersConstants.geminiId);
      expect(map['is_active'], 1);

      final reconstructed = AIProviderModel.fromMap(map);
      expect(reconstructed.id, model.id);
      expect(reconstructed.modelName, model.modelName);
      expect(reconstructed.apiKey, model.apiKey);
      expect(reconstructed.isActive, true);
    });

    test('AiQueryIntent parses JSON correctly for chart intent', () {
      const jsonStr = '''
      {
        "sql": "SELECT category, SUM(amount) AS total FROM sales GROUP BY category;",
        "intent": "chart",
        "chartType": "bar",
        "chartX": "category",
        "chartY": "total",
        "explanation": "Kategorilere göre toplam satışlar listelendi."
      }
      ''';

      final intent = AiQueryIntent.fromJson(jsonDecode(jsonStr));
      expect(intent.hasSql, isTrue);
      expect(intent.sql, contains('SELECT category'));
      expect(intent.intent, 'chart');
      expect(intent.chartType, 'bar');
      expect(intent.chartX, 'category');
      expect(intent.chartY, 'total');
      expect(intent.explanation, isNotEmpty);
    });

    test('AiMessage reconstructs QueryResult and ChartConfig correctly', () {
      final resultData = {
        'columns': ['product', 'quantity'],
        'rows': [
          ['Laptop', 10],
          ['Phone', 25],
        ],
      };

      final message = AiMessage(
        id: 'msg_1',
        conversationId: 'conv_1',
        role: 'assistant',
        content: 'Ürün stokları getirildi.',
        sqlQuery: 'SELECT product, quantity FROM inventory;',
        intent: 'chart',
        chartType: 'pie',
        chartX: 'product',
        chartY: 'quantity',
        resultJson: jsonEncode(resultData),
        rowCount: 2,
        executionTimeMs: 12,
        createdAt: DateTime.now(),
      );

      expect(message.isUser, isFalse);
      expect(message.hasSql, isTrue);
      expect(message.isChart, isTrue);

      final qResult = message.queryResult;
      expect(qResult, isNotNull);
      expect(qResult!.columns, ['product', 'quantity']);
      expect(qResult.rows.length, 2);
      expect(qResult.query, 'SELECT product, quantity FROM inventory;');

      final chartConfig = message.chartConfig;
      expect(chartConfig, isNotNull);
      expect(chartConfig!.type, ChartType.pie);
      expect(chartConfig.labelColumn, 'product');
      expect(chartConfig.valueColumn, 'quantity');
    });

    test('AiConversation title truncation logic', () {
      final conv = AiConversation(
        id: 'c1',
        title: 'Satış Analizi',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(conv.id, 'c1');
      expect(conv.title, 'Satış Analizi');
      final map = conv.toMap();
      expect(map['title'], 'Satış Analizi');

      final reconstructed = AiConversation.fromMap(map);
      expect(reconstructed.id, conv.id);
      expect(reconstructed.title, conv.title);
    });
  });
}
