import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/saved_query.dart';
import '../providers/database_provider.dart';

class SavedQueriesSheet extends ConsumerStatefulWidget {
  final String? activeTable;
  final void Function(String sql, String? tableName) onSelectQuery;
  final void Function(String sql, String? tableName)? onLoadIntoEditor;

  const SavedQueriesSheet({
    super.key,
    this.activeTable,
    required this.onSelectQuery,
    this.onLoadIntoEditor,
  });

  static Future<void> show({
    required BuildContext context,
    String? activeTable,
    required void Function(String sql, String? tableName) onSelectQuery,
    void Function(String sql, String? tableName)? onLoadIntoEditor,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SavedQueriesSheet(
        activeTable: activeTable,
        onSelectQuery: onSelectQuery,
        onLoadIntoEditor: onLoadIntoEditor,
      ),
    );
  }

  @override
  ConsumerState<SavedQueriesSheet> createState() => _SavedQueriesSheetState();
}

class _SavedQueriesSheetState extends ConsumerState<SavedQueriesSheet> {
  int _tabIndex = 0; // 0: Tümü, 1: Yıldızlılar
  bool _filterByCurrentTable = false;

  @override
  void initState() {
    super.initState();
    if (widget.activeTable != null && widget.activeTable!.isNotEmpty) {
      _filterByCurrentTable = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final queryState = ref.watch(queryProvider);
    var list = queryState.savedQueries;

    if (_tabIndex == 1) {
      list = list.where((q) => q.isFavorite).toList();
    }
    if (_filterByCurrentTable && widget.activeTable != null && widget.activeTable!.isNotEmpty) {
      list = list.where((q) => q.tableName == widget.activeTable).toList();
    }

    final totalCount = queryState.savedQueries.length;
    final favoriteCount = queryState.savedQueries.where((q) => q.isFavorite).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sorgu Kütüphanesi',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      widget.activeTable != null && _filterByCurrentTable
                          ? '"${widget.activeTable}" tablosuna özel sorgular'
                          : 'Yıldızlı ve geçmiş SQLite sorgularınız',
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Filter Tabs (Tümü / Yıldızlılar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterTab(0, 'Tümü ($totalCount)', Icons.history_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFilterTab(1, 'Yıldızlılar ($favoriteCount)', Icons.star_rounded),
                ),
              ],
            ),
          ),
          if (widget.activeTable != null && widget.activeTable!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _filterByCurrentTable = !_filterByCurrentTable),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _filterByCurrentTable ? AppColors.accentLight : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _filterByCurrentTable ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _filterByCurrentTable ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 14,
                            color: _filterByCurrentTable ? AppColors.accent : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sadece "${widget.activeTable}" Tablosu',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _filterByCurrentTable ? AppColors.accent : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _tabIndex == 1 ? Icons.star_border_rounded : Icons.search_off_rounded,
                          size: 48,
                          color: AppColors.textMuted.withAlpha(120),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _tabIndex == 1 ? 'Yıldızlı sorgu bulunamadı.' : 'Henüz kayıtlı sorgu yok.',
                          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final item = list[i];
                      return _buildQueryCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index, String label, IconData icon) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withAlpha(30), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? (index == 1 ? AppColors.warning : Colors.white)
                  : (index == 1 ? AppColors.warning : AppColors.textMuted),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueryCard(SavedQuery query) {
    final dateStr = DateFormat('dd.MM HH:mm').format(query.executedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⭐ Star button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(queryProvider.notifier).toggleFavorite(query.id),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    query.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: query.isFavorite ? AppColors.warning : AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  query.queryText,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(queryProvider.notifier).deleteQuery(query.id),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted.withAlpha(150)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (query.tableName != null && query.tableName!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.table_chart_rounded, size: 11, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        query.tableName!,
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              if (query.rowCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.cardMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${query.rowCount} satır',
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                ),
              Text(
                dateStr,
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Copy button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: query.queryText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sorgu kopyalandı', style: GoogleFonts.dmSans()),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.cardMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                ),
              ),
              if (widget.onLoadIntoEditor != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onLoadIntoEditor!(query.queryText, query.tableName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Düzenle',
                      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelectQuery(query.queryText, query.tableName),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Çalıştır',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
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
}

