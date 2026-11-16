import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/database_engine.dart';
import '../../domain/models/ai_chat_model.dart';
import '../../domain/models/ai_provider.dart';
import '../../domain/models/query_result.dart';
import 'database_provider.dart';
import 'connection_provider.dart';

final aiServiceProvider = Provider<AIService>((ref) => const AIService());

// --- AI Settings Provider ---

class AISettingsNotifier extends StateNotifier<List<AIProviderModel>> {
  final DatabaseEngine _engine;
  final AIService _aiService;

  AISettingsNotifier(this._engine, this._aiService) : super([]) {
    loadProviders();
  }

  void loadProviders() {
    state = _engine.getAiProviders();
  }

  void saveProvider(AIProviderModel provider) {
    _engine.saveAiProvider(provider);
    loadProviders();
  }

  void setActive(String id) {
    _engine.setActiveAiProvider(id);
    loadProviders();
  }

  void deleteProvider(String id) {
    _engine.deleteAiProvider(id);
    loadProviders();
  }

  Future<int> testConnection(AIProviderModel provider) async {
    return await _aiService.testConnection(provider);
  }
}

final aiSettingsProvider = StateNotifierProvider<AISettingsNotifier, List<AIProviderModel>>((ref) {
  final engine = ref.watch(databaseEngineProvider);
  final aiService = ref.watch(aiServiceProvider);
  return AISettingsNotifier(engine, aiService);
});

final activeAiProvider = Provider<AIProviderModel?>((ref) {
  final providers = ref.watch(aiSettingsProvider);
  if (providers.isEmpty) return null;
  return providers.where((p) => p.isActive).firstOrNull ??
      providers.where((p) => p.apiKey.isNotEmpty).firstOrNull ??
      providers.firstOrNull;
});

// --- AI Chat State & Notifier ---

class AiChatState {
  final List<AiConversation> conversations;
  final AiConversation? activeConversation;
  final List<AiMessage> messages;
  final String? selectedTable;
  final bool isLoading;
  final bool isGenerating;
  final String? errorMessage;

  const AiChatState({
    this.conversations = const [],
    this.activeConversation,
    this.messages = const [],
    this.selectedTable,
    this.isLoading = false,
    this.isGenerating = false,
    this.errorMessage,
  });

  AiChatState copyWith({
    List<AiConversation>? conversations,
    AiConversation? activeConversation,
    List<AiMessage>? messages,
    String? selectedTable,
    bool? isLoading,
    bool? isGenerating,
    String? errorMessage,
    bool clearActive = false,
    bool clearTable = false,
    bool clearError = false,
  }) {
    return AiChatState(
      conversations: conversations ?? this.conversations,
      activeConversation: clearActive ? null : (activeConversation ?? this.activeConversation),
      messages: messages ?? this.messages,
      selectedTable: clearTable ? null : (selectedTable ?? this.selectedTable),
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  final Ref _ref;

  AiChatNotifier(this._ref) : super(const AiChatState()) {
    loadConversations();
  }

  DatabaseEngine get _engine => _ref.read(databaseEngineProvider);
  AIService get _aiService => _ref.read(aiServiceProvider);

  void loadConversations() {
    final list = _engine.getAiConversations();
    if (list.isEmpty) {
      newConversation();
    } else {
      final active = state.activeConversation != null
          ? (list.where((c) => c.id == state.activeConversation!.id).firstOrNull ?? list.first)
          : list.first;
      final messages = _engine.getAiMessages(active.id);
      state = state.copyWith(
        conversations: list,
        activeConversation: active,
        selectedTable: active.tableName,
        messages: messages,
      );
    }
  }

  void newConversation({String? tableName}) {
    final now = DateTime.now();
    final newConv = AiConversation(
      id: 'conv_${now.microsecondsSinceEpoch}',
      title: 'Yeni Analiz',
      tableName: tableName,
      createdAt: now,
      updatedAt: now,
      messageCount: 0,
    );
    _engine.saveAiConversation(newConv);

    final list = _engine.getAiConversations();
    state = state.copyWith(
      conversations: list,
      activeConversation: newConv,
      selectedTable: tableName,
      messages: [],
      clearError: true,
    );
  }

  void selectConversation(String id) {
    final conv = state.conversations.where((c) => c.id == id).firstOrNull;
    if (conv == null) return;
    final messages = _engine.getAiMessages(id);
    state = state.copyWith(
      activeConversation: conv,
      selectedTable: conv.tableName,
      messages: messages,
      clearError: true,
    );
  }

  void setSelectedTable(String? tableName) {
    state = state.copyWith(selectedTable: tableName, clearTable: tableName == null);
    if (state.activeConversation != null) {
      final updated = state.activeConversation!.copyWith(tableName: tableName);
      _engine.saveAiConversation(updated);
      final list = _engine.getAiConversations();
      state = state.copyWith(conversations: list, activeConversation: updated);
    }
  }

  void renameConversation(String id, String newTitle) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    _engine.updateAiConversationTitle(id, trimmed);
    final list = _engine.getAiConversations();
    final updatedActive = (state.activeConversation?.id == id)
        ? state.activeConversation!.copyWith(title: trimmed)
        : state.activeConversation;
    state = state.copyWith(conversations: list, activeConversation: updatedActive);
  }

  void togglePin(String id) {
    _engine.toggleAiConversationPin(id);
    final list = _engine.getAiConversations();
    final updatedActive = (state.activeConversation?.id == id)
        ? list.where((c) => c.id == id).firstOrNull ?? state.activeConversation
        : state.activeConversation;
    state = state.copyWith(conversations: list, activeConversation: updatedActive);
  }

  void deleteConversation(String id) {
    _engine.deleteAiConversation(id);
    final list = _engine.getAiConversations();
    if (list.isEmpty) {
      newConversation();
    } else {
      final nextActive = list.first;
      final messages = _engine.getAiMessages(nextActive.id);
      state = state.copyWith(
        conversations: list,
        activeConversation: nextActive,
        selectedTable: nextActive.tableName,
        messages: messages,
      );
    }
  }

  Future<void> sendMessage(String userText) async {
    final trimmed = userText.trim();
    if (trimmed.isEmpty || state.isGenerating) return;

    if (state.activeConversation == null) {
      newConversation(tableName: state.selectedTable);
    }

    final activeConv = state.activeConversation!;
    final now = DateTime.now();

    // 1. Add User Message
    final userMsg = AiMessage(
      id: 'msg_${now.microsecondsSinceEpoch}',
      conversationId: activeConv.id,
      role: 'user',
      content: trimmed,
      createdAt: now,
    );
    _engine.saveAiMessage(userMsg);

    final currentMessages = [...state.messages, userMsg];
    state = state.copyWith(
      messages: currentMessages,
      isGenerating: true,
      clearError: true,
    );

    // Auto-update conversation title from first user query
    if (activeConv.title == 'Yeni Analiz' || activeConv.title.isEmpty) {
      final shortTitle = trimmed.length > 28 ? '${trimmed.substring(0, 28)}...' : trimmed;
      _engine.updateAiConversationTitle(activeConv.id, shortTitle);
      final list = _engine.getAiConversations();
      state = state.copyWith(
        conversations: list,
        activeConversation: activeConv.copyWith(title: shortTitle),
      );
    }

    // 2. Resolve Active AI Provider
    final provider = _ref.read(activeAiProvider);
    if (provider == null || provider.apiKey.trim().isEmpty) {
      final errorMsg = AiMessage(
        id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
        conversationId: activeConv.id,
        role: 'assistant',
        content: 'Yapay zeka yanıtı üretebilmek için bir API anahtarı gereklidir.',
        errorMessage: 'Lütfen Ayarlar > Yapay Zeka (AI) ekranından bir sağlayıcı seçip API anahtarınızı girin.',
        createdAt: DateTime.now(),
      );
      _engine.saveAiMessage(errorMsg);
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isGenerating: false,
      );
      return;
    }

    // 3. Prepare Schema & Dialect
    final tablesState = _ref.read(tablesProvider);
    final session = _ref.read(sessionProvider);
    final dialect = session.dialect;
    final connState = _ref.read(connectionsProvider);
    final isRemote = connState.activeConnection != null;
    final sourceDesc = isRemote
        ? 'Uzak Veritabanı Sunucusu: ${connState.activeConnection!.name} (${connState.activeConnection!.type.label}) - Veritabanı: ${connState.activeConnection!.database}'
        : 'Yerel Veritabanı (İçe aktarılan CSV / Excel dosyaları ve yerel tablolar)';

    var tables = tablesState.tables;
    if (tables.isEmpty) {
      try {
        tables = await session.getTables();
      } catch (_) {}
    }

    try {
      final intent = await _aiService.generateQueryIntent(
        question: trimmed,
        tables: tables,
        activeTableName: state.selectedTable,
        dataSourceDescription: sourceDesc,
        previousMessages: state.messages,
        dialect: dialect,
        provider: provider,
      );

      QueryResult? queryResult;
      String? execError;
      int execTime = 0;
      int rowsCount = 0;
      String? serializedResult;

      // 4. Run SQL Query if generated
      if (intent.hasSql && intent.sql != null) {
        final cleanSql = intent.sql!;
        final stopwatch = Stopwatch()..start();
        try {
          final qResult = await session.execute(cleanSql, tableName: state.selectedTable);
          queryResult = qResult;
          stopwatch.stop();
          execTime = stopwatch.elapsedMilliseconds;
          if (qResult.hasError) {
            execError = qResult.error;
          } else {
            rowsCount = qResult.rows.length;
            // Cap serialized rows to 100 to maintain high performance & low memory
            final cappedRows = qResult.rows.take(100).toList();
            serializedResult = jsonEncode({
              'columns': qResult.columns,
              'rows': cappedRows,
            });
          }
        } catch (e) {
          stopwatch.stop();
          execError = e.toString();
        }
      }

      // 5. Determine chart columns if chart was requested but columns were omitted
      String? finalChartX = intent.chartX;
      String? finalChartY = intent.chartY;
      if (intent.intent == 'chart' && queryResult != null && !queryResult.hasError && queryResult.columns.isNotEmpty) {
        if (finalChartX == null || !queryResult.columns.contains(finalChartX)) {
          finalChartX = queryResult.columns.first;
        }
        if (finalChartY == null || !queryResult.columns.contains(finalChartY)) {
          final numCol = queryResult.columns.firstWhere(
            (c) => queryResult!.rows.isNotEmpty && queryResult.rows.first[queryResult.columns.indexOf(c)] is num,
            orElse: () => queryResult!.columns.length > 1 ? queryResult.columns[1] : queryResult.columns.first,
          );
          finalChartY = numCol;
        }
      }

      final assistantMsg = AiMessage(
        id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
        conversationId: activeConv.id,
        role: 'assistant',
        content: intent.explanation,
        sqlQuery: intent.hasSql ? intent.sql : null,
        resultJson: serializedResult,
        chartType: intent.intent == 'chart' ? (intent.chartType ?? 'bar') : null,
        chartX: finalChartX,
        chartY: finalChartY,
        intent: intent.intent,
        executionTimeMs: execTime,
        rowCount: rowsCount,
        errorMessage: execError,
        createdAt: DateTime.now(),
      );

      _engine.saveAiMessage(assistantMsg);

      final updatedConvs = _engine.getAiConversations();
      state = state.copyWith(
        conversations: updatedConvs,
        messages: [...state.messages, assistantMsg],
        isGenerating: false,
      );
    } catch (e) {
      final errorMsg = AiMessage(
        id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
        conversationId: activeConv.id,
        role: 'assistant',
        content: 'İşlem sırasında bir hata oluştu.',
        errorMessage: e.toString(),
        createdAt: DateTime.now(),
      );
      _engine.saveAiMessage(errorMsg);
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isGenerating: false,
      );
    }
  }
}

final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(ref);
});
