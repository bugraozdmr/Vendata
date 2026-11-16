import 'dart:convert';
import 'chart_config.dart';
import 'query_result.dart';

class AiConversation {
  final String id;
  final String title;
  final String? tableName;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  const AiConversation({
    required this.id,
    required this.title,
    this.tableName,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  AiConversation copyWith({
    String? id,
    String? title,
    String? tableName,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? messageCount,
  }) {
    return AiConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      tableName: tableName ?? this.tableName,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'table_name': tableName,
        'is_pinned': isPinned ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AiConversation.fromMap(Map<String, dynamic> map, {int messageCount = 0}) {
    return AiConversation(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Yeni Sohbet',
      tableName: map['table_name'] as String?,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
      messageCount: messageCount,
    );
  }
}

class AiMessage {
  final String id;
  final String conversationId;
  final String role; // 'user' | 'assistant'
  final String content;
  final String? sqlQuery;
  final String? resultJson; // Serialized QueryResult
  final String? chartType; // 'bar' | 'pie' | 'line'
  final String? chartX;
  final String? chartY;
  final String? intent; // 'chart' | 'table' | 'scalar' | 'text'
  final int executionTimeMs;
  final int rowCount;
  final String? errorMessage;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.sqlQuery,
    this.resultJson,
    this.chartType,
    this.chartX,
    this.chartY,
    this.intent,
    this.executionTimeMs = 0,
    this.rowCount = 0,
    this.errorMessage,
    required this.createdAt,
  });

  bool get isUser => role == 'user';
  bool get hasSql => sqlQuery != null && sqlQuery!.trim().isNotEmpty;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
  bool get isChart => intent == 'chart' && chartType != null;
  bool get isScalar => intent == 'scalar';
  bool get isTable => intent == 'table';

  QueryResult? get queryResult {
    if (resultJson == null || resultJson!.isEmpty) return null;
    try {
      final decoded = jsonDecode(resultJson!);
      if (decoded is Map<String, dynamic>) {
        final cols = List<String>.from(decoded['columns'] ?? []);
        final rawRows = decoded['rows'] as List<dynamic>? ?? [];
        final rows = rawRows.map((r) => List<dynamic>.from(r as List)).toList();
        return QueryResult(
          columns: cols,
          rows: rows,
          executionTimeMs: executionTimeMs,
          query: sqlQuery ?? '',
          error: errorMessage,
        );
      }
    } catch (_) {}
    return null;
  }

  ChartConfig? get chartConfig {
    if (chartType == null || chartX == null || chartY == null) return null;
    ChartType cType;
    switch (chartType) {
      case 'pie':
        cType = ChartType.pie;
        break;
      case 'line':
        cType = ChartType.line;
        break;
      default:
        cType = ChartType.bar;
    }
    return ChartConfig(
      type: cType,
      labelColumn: chartX!,
      valueColumn: chartY!,
      maxItems: 15,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role,
        'content': content,
        'sql_query': sqlQuery,
        'result_json': resultJson,
        'chart_type': chartType,
        'chart_x': chartX,
        'chart_y': chartY,
        'intent': intent,
        'execution_time_ms': executionTimeMs,
        'row_count': rowCount,
        'error_message': errorMessage,
        'created_at': createdAt.toIso8601String(),
      };

  factory AiMessage.fromMap(Map<String, dynamic> map) {
    return AiMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String? ?? '',
      sqlQuery: map['sql_query'] as String?,
      resultJson: map['result_json'] as String?,
      chartType: map['chart_type'] as String?,
      chartX: map['chart_x'] as String?,
      chartY: map['chart_y'] as String?,
      intent: map['intent'] as String?,
      executionTimeMs: (map['execution_time_ms'] as int?) ?? 0,
      rowCount: (map['row_count'] as int?) ?? 0,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AiQueryIntent {
  final String? sql;
  final String intent; // 'chart', 'table', 'scalar', 'text'
  final String? chartType; // 'bar', 'pie', 'line'
  final String? chartX;
  final String? chartY;
  final String explanation;

  const AiQueryIntent({
    this.sql,
    this.intent = 'text',
    this.chartType,
    this.chartX,
    this.chartY,
    required this.explanation,
  });

  factory AiQueryIntent.fromJson(Map<String, dynamic> json) {
    return AiQueryIntent(
      sql: json['sql'] as String?,
      intent: json['intent'] as String? ?? 'text',
      chartType: json['chartType'] as String?,
      chartX: json['chartX'] as String?,
      chartY: json['chartY'] as String?,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  bool get hasSql => sql != null && sql!.trim().isNotEmpty;
}
