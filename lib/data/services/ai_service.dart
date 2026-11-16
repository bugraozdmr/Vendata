import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/ai_providers_constants.dart';
import '../../domain/models/ai_chat_model.dart';
import '../../domain/models/ai_provider.dart';
import '../../domain/models/table_schema.dart';
import 'db_session.dart';

class AIService {
  const AIService();

  /// User question to structured query intent (SQL + chart/table/scalar intent).
  Future<AiQueryIntent> generateQueryIntent({
    required String question,
    required List<TableSchema> tables,
    String? activeTableName,
    String? dataSourceDescription,
    List<AiMessage> previousMessages = const [],
    required DbDialect dialect,
    required AIProviderModel provider,
  }) async {
    final schemaDescription = _formatSchemaDescription(tables, activeTableName);
    final historyContext = _formatHistoryContext(previousMessages);
    final dialectName = dialect.label;
    final sourceInfo = dataSourceDescription ?? (activeTableName != null ? 'Tablo: $activeTableName' : 'Tüm Tablolar');

    final systemPrompt = '''
You are Vendata AI, an expert SQL data analyst assistant.
Data Source: $sourceInfo
Active Scope: ${activeTableName != null ? 'Table "$activeTableName"' : 'All Tables'}
Convert the user's natural language question into an executable $dialectName query, chart visual, or clear Turkish explanation based strictly on the provided schema.

Available Database Schema:
$schemaDescription

Dialect: $dialectName
${historyContext.isNotEmpty ? 'Conversation context:\n$historyContext\n' : ''}

Output Rules:
1. Output ONLY a valid JSON object. No Markdown code fences, no extra text.
2. Structure:
{
  "sql": "SELECT ...;" or null,
  "intent": "chart" | "table" | "scalar" | "text",
  "chartType": "bar" | "pie" | "line" | null,
  "chartX": "category_column_name_or_null",
  "chartY": "numeric_column_name_or_null",
  "explanation": "Kısa Türkçe açıklama."
}
3. Guidelines:
- If user asks for a chart/distribution (grafik, pasta, çizgi, sütun), set intent="chart", chartType="bar"|"pie"|"line", and choose appropriate X and Y columns.
- If user asks for a single person/top metric (en çok, en az, toplam kaç), set intent="scalar".
- If user asks for general data listing, set intent="table".
- If user asks to explain columns, tables, or what the data means (e.g. "sütunları açıkla", "bu veriler ne", "tabloyu anlat", "şema nedir"), set sql=null, intent="text", and explain the columns and data clearly in Turkish bullet points in "explanation".
- If question is conversational without data query, set sql=null, intent="text", explanation="Türkçe yanıt".
- When an active table is selected, focus queries and explanations exclusively on that table unless the user explicitly requests another.
- Always write valid, safe $dialectName queries. Never write DROP, DELETE, or ALTER. Limit unconstrained queries to 50 rows.
''';

    final userPrompt = question.trim();

    final rawContent = await _callModel(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      provider: provider,
      maxTokens: 1200,
    );

    return _parseIntentFromJson(rawContent);
  }

  /// Direct Natural Language to SQL converter (for SQL screen editor).
  Future<String> generateSqlFromPrompt({
    required String prompt,
    required List<TableSchema> tables,
    String? activeTableName,
    required DbDialect dialect,
    required AIProviderModel provider,
  }) async {
    final schemaDescription = _formatSchemaDescription(tables, activeTableName);
    final dialectName = dialect.label;

    final systemPrompt = '''
You are a senior database engineer. Convert the user's request into a clean, valid $dialectName SQL query.
Schema:
$schemaDescription

Rules:
1. Return ONLY the SQL query. No explanations, no markdown formatting, no comments.
2. Dialect: $dialectName.
''';

    final raw = await _callModel(
      systemPrompt: systemPrompt,
      userPrompt: prompt.trim(),
      provider: provider,
      maxTokens: 300,
    );

    return _cleanSqlOutput(raw);
  }

  /// Explain a SQL query in Turkish.
  Future<String> explainSql({
    required String sql,
    required List<TableSchema> tables,
    required AIProviderModel provider,
  }) async {
    final schemaDescription = _formatSchemaDescription(tables, null);

    final systemPrompt = '''
You are a database teacher. Explain what the given SQL query does in clear, concise Turkish bullet points.
Schema:
$schemaDescription
Keep the explanation under 4 sentences.
''';

    return await _callModel(
      systemPrompt: systemPrompt,
      userPrompt: sql,
      provider: provider,
      maxTokens: 350,
    );
  }

  /// Test connection with API Key and return round-trip latency in ms.
  Future<int> testConnection(AIProviderModel provider) async {
    if (provider.apiKey.trim().isEmpty) {
      throw Exception('API Anahtarı boş bırakılamaz.');
    }

    final stopwatch = Stopwatch()..start();
    final res = await _callModel(
      systemPrompt: 'You are a test agent. Respond only with "OK".',
      userPrompt: 'PING',
      provider: provider,
      maxTokens: 10,
    );
    stopwatch.stop();

    if (res.isEmpty) {
      throw Exception('Modelden boş yanıt alındı.');
    }
    return stopwatch.elapsedMilliseconds;
  }

  // --- Internal Model Caller ---

  Future<String> _callModel({
    required String systemPrompt,
    required String userPrompt,
    required AIProviderModel provider,
    int maxTokens = 500,
  }) async {
    if (provider.apiKey.trim().isEmpty) {
      throw Exception('API Anahtarı girilmemiş. Lütfen Ayarlar > AI Sağlayıcıları ekranından API anahtarınızı girin.');
    }

    final isGemini = provider.providerType == 'gemini';

    if (isGemini) {
      return await _callGemini(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        provider: provider,
        maxTokens: maxTokens,
      );
    } else {
      return await _callOpenAiCompatible(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        provider: provider,
        maxTokens: maxTokens,
      );
    }
  }

  Future<String> _callGemini({
    required String systemPrompt,
    required String userPrompt,
    required AIProviderModel provider,
    required int maxTokens,
  }) async {
    var modelName = provider.modelName.trim();
    if (modelName.isEmpty ||
        modelName.contains('2.0-flash') ||
        modelName.contains('1.5-flash') ||
        modelName.contains('2.5-flash')) {
      modelName = 'gemini-3.5-flash-lite';
    }

    final apiKey = provider.apiKey.trim();

    Future<http.Response> requestModel(String model) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );
      final payload = {
        'contents': [
          {
            'parts': [
              {'text': '$systemPrompt\n\nUser Question:\n$userPrompt'}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': maxTokens,
        }
      };
      return http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));
    }

    var response = await requestModel(modelName);

    // If requested model was retired (404) or overloaded (503), automatically fallback to gemini-3.5-flash-lite
    if ((response.statusCode == 404 || response.statusCode == 503) && modelName != 'gemini-3.5-flash-lite') {
      response = await requestModel('gemini-3.5-flash-lite');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          return parts.first['text'] as String? ?? '';
        }
      }
      return '';
    } else {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Gemini Hatası (${response.statusCode}): $body');
    }
  }

  Future<String> _callOpenAiCompatible({
    required String systemPrompt,
    required String userPrompt,
    required AIProviderModel provider,
    required int maxTokens,
  }) async {
    final preset = AIProvidersConstants.getPresetByType(provider.providerType);
    final endpoint = (provider.baseUrl != null && provider.baseUrl!.trim().isNotEmpty)
        ? provider.baseUrl!.trim()
        : (preset?.defaultBaseUrl ?? 'https://api.openai.com/v1/chat/completions');

    final url = Uri.parse(endpoint);
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer ${provider.apiKey.trim()}',
    };

    if (provider.providerType == 'openrouter') {
      headers['HTTP-Referer'] = 'https://vendata.app';
      headers['X-Title'] = 'Vendata';
    }

    final payload = {
      'model': provider.modelName.trim(),
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.2,
      'max_tokens': maxTokens,
    };

    final response = await http
        .post(
          url,
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 35));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final msg = choices.first['message'] as Map<String, dynamic>?;
        return msg?['content'] as String? ?? '';
      }
      return '';
    } else {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('${provider.name} Hatası (${response.statusCode}): $body');
    }
  }

  // --- Formatters & Parsers ---

  String _formatSchemaDescription(List<TableSchema> tables, String? activeTable) {
    if (tables.isEmpty) return 'No tables available.';

    final relevantTables = activeTable != null && activeTable.isNotEmpty
        ? tables.where((t) => t.name == activeTable).toList()
        : tables;

    final targetList = relevantTables.isNotEmpty ? relevantTables : tables;

    final sb = StringBuffer();
    for (final table in targetList) {
      sb.writeln('Table: ${table.name} (${table.rowCount} rows)');
      final cols = table.columns.map((c) => '${c.name} (${c.type})').join(', ');
      sb.writeln('  Columns: $cols');
    }
    return sb.toString();
  }

  String _formatHistoryContext(List<AiMessage> messages) {
    if (messages.isEmpty) return '';
    // Only send the last 2-3 queries to preserve ultra-low token count
    final recent = messages.reversed.take(4).toList().reversed.toList();
    final sb = StringBuffer();
    for (final msg in recent) {
      if (msg.isUser) {
        sb.writeln('User: ${msg.content}');
      } else if (msg.hasSql) {
        sb.writeln('SQL: ${msg.sqlQuery}');
      }
    }
    return sb.toString();
  }

  AiQueryIntent _parseIntentFromJson(String rawJson) {
    final cleaned = _extractJsonBlock(rawJson);
    try {
      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      final rawSql = map['sql'] as String?;
      final cleanSql = AiQueryIntent.sanitizeSql(rawSql);
      final intent = map['intent'] as String? ?? (cleanSql != null ? 'table' : 'text');
      final chartType = map['chartType'] as String?;
      final chartX = map['chartX'] as String?;
      final chartY = map['chartY'] as String?;
      final explanation = map['explanation'] as String? ?? '';

      return AiQueryIntent(
        sql: cleanSql,
        intent: intent,
        chartType: chartType,
        chartX: chartX,
        chartY: chartY,
        explanation: explanation.isNotEmpty ? explanation : 'Sorgu oluşturuldu.',
      );
    } catch (_) {
      // Fallback 1: Extract "sql" and "explanation" using regex if JSON was truncated
      final sqlMatch = RegExp(r'"sql"\s*:\s*"((?:\\.|[^"\\])*)"', dotAll: true).firstMatch(cleaned);
      final explMatch = RegExp(r'"explanation"\s*:\s*"((?:\\.|[^"\\])*)"?', dotAll: true).firstMatch(cleaned);
      final intentMatch = RegExp(r'"intent"\s*:\s*"([a-zA-Z]+)"').firstMatch(cleaned);

      String? extractedSql;
      if (sqlMatch != null) {
        var sql = sqlMatch.group(1) ?? '';
        sql = sql.replaceAll(r'\"', '"').replaceAll(r'\n', '\n').trim();
        extractedSql = AiQueryIntent.sanitizeSql(sql);
      } else {
        // Fallback for truncated/unclosed sql string:
        final unclosed = RegExp(r'"sql"\s*:\s*"((?:SELECT|WITH|SHOW|DESCRIBE)\b[^"\r\n]+)', caseSensitive: false, dotAll: true).firstMatch(cleaned);
        if (unclosed != null) {
          extractedSql = AiQueryIntent.sanitizeSql(unclosed.group(1));
        }
      }

      if (extractedSql != null) {
        var explanation = explMatch?.group(1)?.replaceAll(r'\"', '"').trim() ?? 'SQL sorgusu oluşturuldu.';
        final intent = intentMatch?.group(1) ?? 'table';

        return AiQueryIntent(
          sql: extractedSql,
          intent: intent,
          explanation: explanation,
        );
      }

      // Fallback 2: Check if raw text starts with SELECT/WITH (clean SQL only, never JSON)
      final upper = cleaned.toUpperCase();
      if (!cleaned.contains('{') && (upper.startsWith('SELECT ') || upper.startsWith('WITH '))) {
        final extracted = AiQueryIntent.sanitizeSql(cleaned);
        if (extracted != null) {
          return AiQueryIntent(
            sql: extracted,
            intent: 'table',
            explanation: 'SQL sorgusu oluşturuldu.',
          );
        }
      }

      return AiQueryIntent(
        sql: null,
        intent: 'text',
        explanation: rawJson.trim(),
      );
    }
  }

  String _extractJsonBlock(String text) {
    var trimmed = text.trim();
    if (trimmed.startsWith('```json')) {
      trimmed = trimmed.substring(7);
    } else if (trimmed.startsWith('```')) {
      trimmed = trimmed.substring(3);
    }
    if (trimmed.endsWith('```')) {
      trimmed = trimmed.substring(0, trimmed.length - 3);
    }
    trimmed = trimmed.trim();

    final startIdx = trimmed.indexOf('{');
    final endIdx = trimmed.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return trimmed.substring(startIdx, endIdx + 1);
    }
    return trimmed;
  }

  String _cleanSqlOutput(String raw) {
    var s = raw.trim();
    if (s.startsWith('```sql')) {
      s = s.substring(6);
    } else if (s.startsWith('```')) {
      s = s.substring(3);
    }
    if (s.endsWith('```')) {
      s = s.substring(0, s.length - 3);
    }
    final sanitized = AiQueryIntent.sanitizeSql(s);
    return sanitized ?? s.trim();
  }
}
