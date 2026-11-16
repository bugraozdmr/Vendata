import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/ai_chat_model.dart';
import '../../domain/models/db_connection.dart';
import '../../domain/models/query_result.dart';
import '../providers/ai_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/database_provider.dart';
import '../widgets/data_grid_table.dart';
import '../widgets/interactive_chart.dart';
import 'ai_settings_screen.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final void Function(String sql, String? tableName)? onNavigateToSql;
  final VoidCallback? onBackToHome;

  const AiChatScreen({super.key, this.onNavigateToSql, this.onBackToHome});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? presetText]) {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty) return;

    if (presetText == null) {
      _textController.clear();
    }
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final activeAi = ref.watch(activeAiProvider);
    final tablesState = ref.watch(tablesProvider);
    final connState = ref.watch(connectionsProvider);
    final activeConn = connState.activeConnection;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    ref.listen(aiChatProvider.select((s) => s.messages.length), (prev, next) {
      if (next > (prev ?? 0)) {
        _scrollToBottom();
      }
    });

    final availableTables = tablesState.tables;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, chatState, activeAi, availableTables, activeConn),

            // Message List or Empty Suggestions
            Expanded(
              child: chatState.messages.isEmpty
                  ? _buildEmptyState(availableTables, chatState.selectedTable, activeAi)
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final msg = chatState.messages[index];
                        return _MessageBubble(
                          message: msg,
                          activeAiLogo: activeAi?.assetLogo,
                          onNavigateToSql: widget.onNavigateToSql,
                        );
                      },
                    ),
            ),

            // Loading indicator when generating
            if (chatState.isGenerating) _buildGeneratingIndicator(),

            // Bottom Input Bar
            _buildInputBar(isLandscape),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AiChatState chatState,
    dynamic activeAi,
    List<dynamic> availableTables,
    DbConnection? activeConn,
  ) {
    final activeConv = chatState.activeConversation;
    final title = activeConv?.title ?? 'AI Sohbet';
    final isRemote = activeConn != null;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border.withAlpha(50))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (!isLandscape) ...[
                IconButton(
                  tooltip: 'Tablolara Dön',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  icon: Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
                  onPressed: widget.onBackToHome ?? () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
              ],
              // Active AI Brand Logo or Sparkle
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: activeAi != null
                    ? Image.asset(
                        activeAi.assetLogo,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
                      )
                    : Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              // Title & Conversations picker
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showConversationsSheet(context, chatState),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (activeConv?.isPinned == true) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.push_pin_rounded, size: 14, color: AppColors.accent),
                      ],
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

              // Active AI Model Pill
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AISettingsScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cardMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (activeAi != null) ...[
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: Image.asset(
                            activeAi.assetLogo,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: (activeAi.apiKey.isNotEmpty)
                                    ? AppColors.success
                                    : AppColors.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ] else ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          activeAi != null ? activeAi.modelName : 'Model Yok',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // New chat button
              IconButton(
                tooltip: 'Yeni Sohbet Başlat',
                icon: Icon(Icons.edit_note_rounded, size: 24, color: AppColors.textPrimary),
                onPressed: () {
                  ref.read(aiChatProvider.notifier).newConversation(tableName: chatState.selectedTable);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Source and Table filter selector row
          Row(
            children: [
              // Data source button (Local vs Server)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showSourcePickerSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isRemote ? AppColors.accentLight : AppColors.cardMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isRemote ? AppColors.accent.withAlpha(80) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRemote) ...[
                        Image.asset(
                          activeConn.type.assetLogo,
                          width: 14,
                          height: 14,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.dns_rounded, size: 14, color: AppColors.accent),
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(
                            activeConn.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.folder_open_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Yerel',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down_rounded, size: 16, color: isRemote ? AppColors.accent : AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Table filter chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // "Tümü" chip
                      _buildTableChip(
                        label: 'Tüm Tablolar',
                        isSelected: chatState.selectedTable == null,
                        onTap: () => ref.read(aiChatProvider.notifier).setSelectedTable(null),
                      ),
                      ...availableTables.map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _buildTableChip(
                            label: t.name,
                            isSelected: chatState.selectedTable == t.name,
                            onTap: () => ref.read(aiChatProvider.notifier).setSelectedTable(t.name),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(List<dynamic> tables, String? selectedTable, dynamic activeAi) {
    final hasTable = selectedTable != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: activeAi != null
                ? Image.asset(
                    activeAi.assetLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 28),
                  )
                : Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'Verilerinize Soru Sorun',
            style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            hasTable
                ? '"$selectedTable" tablosu aktif. Sütunları açıklayabilir, özet çıkartabilir veya grafik çizdirebilirsiniz.'
                : 'Yapay zeka verilerinizi analiz eder, SQL sorgusunu üretir ve grafik veya tablo olarak anında görselleştirir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, height: 1.4, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Örnek Sorular (Dokunarak Deneyin):',
              style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasTable) ...[
                _buildPromptChip('📌 "$selectedTable" sütunlarını ve veri tiplerini açıkla'),
                _buildPromptChip('📊 "$selectedTable" tablosundaki ilk 5 kaydı ve özet verileri getir'),
                _buildPromptChip('🔍 Eksik veya null olan satırları bul'),
                _buildPromptChip('📈 Sayısal sütunların ortalamasını ve dağılımını göster'),
              ] else ...[
                _buildPromptChip('🗄️ Veritabanındaki tüm tabloları ve şemayı özetle'),
                _buildPromptChip('📋 Tablolarda kaçar adet kayıt var listele'),
                _buildPromptChip('🔗 Tablolar arasındaki olası ilişkileri ve anahtarları göster'),
                _buildPromptChip('⚡ En çok veri içeren tabloları listele'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChip(String prompt) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _sendMessage(prompt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                prompt,
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          ),
          const SizedBox(width: 8),
          Text(
            'Yapay zeka sorguluyor ve analiz ediyor...',
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isLandscape) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 8, 16, isLandscape ? 8.0 : 8.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border.withAlpha(50))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Verinize bir soru sorun...',
                    hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _sendMessage(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.accent.withAlpha(50), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.arrow_upward_rounded, size: 22, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConversationsSheet(BuildContext context, AiChatState chatState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

        return Consumer(
          builder: (context, ref, _) {
            final liveState = ref.watch(aiChatProvider);
            final convs = liveState.conversations;

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kayıtlı Sohbetler',
                        style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    label: Text('Yeni Sohbet Başlat', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(aiChatProvider.notifier).newConversation();
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: convs.isEmpty
                        ? Center(
                            child: Text('Kayıtlı sohbet bulunamadı.', style: GoogleFonts.dmSans(color: AppColors.textMuted)),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: convs.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final c = convs[idx];
                              final isSelected = c.id == liveState.activeConversation?.id;

                              return Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.accentLight : AppColors.cardMuted,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
                                  title: Row(
                                    children: [
                                      if (c.isPinned) ...[
                                        Icon(Icons.push_pin_rounded, size: 14, color: AppColors.accent),
                                        const SizedBox(width: 5),
                                      ],
                                      Expanded(
                                        child: Text(
                                          c.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected ? AppColors.accent : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${dateFormat.format(c.updatedAt)} · ${c.messageCount} mesaj',
                                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Pin Button
                                      IconButton(
                                        tooltip: c.isPinned ? 'Sabitlemeyi Kaldır' : 'Başa Sabitle',
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          c.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                          size: 18,
                                          color: c.isPinned ? AppColors.accent : AppColors.textMuted,
                                        ),
                                        onPressed: () {
                                          ref.read(aiChatProvider.notifier).togglePin(c.id);
                                        },
                                      ),
                                      // Rename Button
                                      IconButton(
                                        tooltip: 'İsim Değiştir',
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                                        onPressed: () {
                                          _showRenameDialog(context, c);
                                        },
                                      ),
                                      // Delete Button
                                      IconButton(
                                        tooltip: 'Sohbeti Sil',
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                        onPressed: () {
                                          ref.read(aiChatProvider.notifier).deleteConversation(c.id);
                                        },
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    ref.read(aiChatProvider.notifier).selectConversation(c.id);
                                    Navigator.pop(ctx);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, AiConversation conv) {
    final controller = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Sohbeti Yeniden Adlandır',
            style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Sohbet başlığı...',
              hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.cardMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text('İptal', style: GoogleFonts.dmSans(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  ref.read(aiChatProvider.notifier).renameConversation(conv.id, text);
                }
                Navigator.pop(dlgCtx);
              },
              child: Text('Kaydet', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _showSourcePickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final connState = ref.watch(connectionsProvider);
            final activeConn = connState.activeConnection;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.storage_rounded, size: 20, color: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Veri Kaynağı Seçin',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Yapay zekanın sorgulayacağı veritabanı veya dosyayı belirleyin',
                                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        // Option 1: Local SQLite / Imported Files
                        ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.cardMuted,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(Icons.folder_open_rounded, size: 20, color: AppColors.textPrimary),
                          ),
                          title: Text(
                            'Yerel Veritabanı (CSV / Excel)',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Cihazdaki yerel tablolar ve içe aktarılan dosyalar',
                            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                          ),
                          trailing: activeConn == null
                              ? Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 22)
                              : null,
                          onTap: () {
                            if (activeConn != null) {
                              ref.read(connectionsProvider.notifier).disconnect();
                              ref.read(aiChatProvider.notifier).setSelectedTable(null);
                            }
                            Navigator.pop(ctx);
                          },
                        ),

                        if (connState.connections.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Text(
                              'KAYITLI UZAK SUNUCULAR',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          ...connState.connections.map((conn) {
                            final isSelected = activeConn?.id == conn.id;
                            final health = connState.healthFor(conn.id);

                            return ListTile(
                              leading: Container(
                                width: 38,
                                height: 38,
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppColors.cardMuted,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Image.asset(
                                  conn.type.assetLogo,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.dns_rounded, size: 20, color: AppColors.accent),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      conn.name,
                                      style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: health.isOnline
                                          ? AppColors.success
                                          : (health.isOffline ? AppColors.error : AppColors.textMuted),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${conn.type.label} • ${conn.database} (${conn.host})',
                                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 22)
                                  : (connState.isConnecting
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                        )
                                      : null),
                              onTap: connState.isConnecting
                                  ? null
                                  : () async {
                                      if (!isSelected) {
                                        final success = await ref.read(connectionsProvider.notifier).connect(conn);
                                        if (success) {
                                          ref.read(aiChatProvider.notifier).setSelectedTable(null);
                                          await ref.read(tablesProvider.notifier).refreshTables();
                                        } else if (context.mounted) {
                                          final err = ref.read(connectionsProvider).errorMessage ?? 'Bağlantı kurulamadı.';
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(err),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final AiMessage message;
  final String? activeAiLogo;
  final void Function(String sql, String? tableName)? onNavigateToSql;

  const _MessageBubble({
    required this.message,
    this.activeAiLogo,
    this.onNavigateToSql,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  int _viewMode = 0; // 0: Grafik, 1: Tablo

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    if (msg.isUser) {
      return _buildUserBubble(msg);
    } else {
      return _buildAssistantBubble(msg);
    }
  }

  Widget _buildUserBubble(AiMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF15161A), // Obsidian
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          msg.content,
          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(AiMessage msg) {
    final queryResult = msg.queryResult;
    final chartConfig = msg.chartConfig;
    final hasVisualization = queryResult != null && queryResult.rows.isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Header with Model badge & time
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.activeAiLogo != null
                      ? Image.asset(
                          widget.activeAiLogo!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.accent),
                        )
                      : Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.accent),
                ),
                const SizedBox(width: 8),
                Text(
                  'Vendata AI',
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const Spacer(),
                if (msg.executionTimeMs > 0)
                  Text(
                    '${msg.executionTimeMs} ms · ${msg.rowCount} satır',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // AI Natural text explanation
            if (msg.content.isNotEmpty)
              Text(
                msg.content,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
              ),

            // Error banner if any
            if (msg.hasError) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorWash,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        msg.errorMessage!,
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Generated SQL Code Box
            if (msg.hasSql) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF15161A), // Obsidian
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with Copy & Open in SQL buttons
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(40),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.code_rounded, size: 13, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text(
                            'SQL',
                            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
                          ),
                          const Spacer(),
                          // Copy button
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: msg.sqlQuery!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('SQL kopyalandı'), duration: Duration(seconds: 1)),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text('Kopyala', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white70)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Open in SQL Screen
                          if (widget.onNavigateToSql != null)
                            GestureDetector(
                              onTap: () => widget.onNavigateToSql!(msg.sqlQuery!, null),
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_new_rounded, size: 12, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Konsolda Aç',
                                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        msg.sqlQuery!,
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFFF0F0F0), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Visual Results (Chart or Table or Scalar)
            if (hasVisualization) ...[
              const SizedBox(height: 14),

              // If scalar (1 row, <= 2 columns): Big impact stat card
              if (msg.isScalar || (queryResult.rows.length == 1 && queryResult.columns.length <= 2)) ...[
                _buildScalarCard(queryResult),
              ] else ...[
                // Mode Toggle if chart config is present
                if (chartConfig != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildViewModeButton(0, 'Grafik', Icons.bar_chart_rounded),
                      const SizedBox(width: 6),
                      _buildViewModeButton(1, 'Tablo', Icons.table_chart_rounded),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Visualization content
                if (chartConfig != null && _viewMode == 0)
                  SizedBox(
                    height: 250,
                    child: InteractiveChart(
                      result: queryResult,
                      config: chartConfig,
                      onConfigChanged: (_) {},
                    ),
                  )
                else
                  SizedBox(
                    height: 240,
                    child: DataGridTable(
                      result: queryResult,
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScalarCard(QueryResult result) {
    final firstRow = result.rows.first;
    final primaryVal = firstRow.isNotEmpty ? firstRow.last.toString() : '—';
    final label = firstRow.length > 1 ? firstRow.first.toString() : result.columns.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              primaryVal,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(int mode, String label, IconData icon) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
