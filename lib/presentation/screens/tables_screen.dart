import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../domain/models/recent_file.dart';
import '../../domain/models/saved_query.dart';
import '../../domain/models/table_schema.dart';
import '../providers/database_provider.dart';

class TablesScreen extends ConsumerStatefulWidget {
  final void Function(String tableName) onNavigateToSql;

  const TablesScreen({super.key, required this.onNavigateToSql});

  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'tsv', 'sql', 'db', 'sqlite'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final file = files.first;
      await ref.read(tablesProvider.notifier).importFromFile(
            filePath: file.path!,
            fileName: file.name,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablesState = ref.watch(tablesProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Veriler',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -1.0,
                  ),
                ),
                if (tablesState.tables.isNotEmpty)
                  _buildIconBtn(
                    Icons.delete_sweep_rounded,
                    AppColors.error,
                    () => _confirmClearAll(context),
                  ),
              ],
            ),
            if (tablesState.isLoading) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.cardMuted,
                  minHeight: 3,
                ),
              ),
            ],
            if (tablesState.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorBanner(tablesState.errorMessage!),
            ],
            const SizedBox(height: 20),
            _buildUploadCard(),
            if (tablesState.recentFiles.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildRecentFiles(tablesState.recentFiles),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Text(
                  'Tablolar',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tablesState.tables.length}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tablesState.tables.isEmpty)
              _buildEmptyState()
            else
              ...tablesState.tables.map((t) => _buildTableCard(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(error, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.accent, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              'Dosya Yükle',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Excel, CSV veya SQL',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFiles(List<RecentFile> recentFiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Açılanlar',
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recentFiles.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _buildRecentFileCard(recentFiles[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentFileCard(RecentFile file) {
    final isExcel = file.fileType.contains('EXCEL') || file.fileName.endsWith('.xlsx') || file.fileName.endsWith('.xls');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(tablesProvider.notifier).reimportRecentFile(file),
      child: Container(
        width: 170,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isExcel ? AppColors.successWash : AppColors.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isExcel ? Icons.table_view_rounded : Icons.description_outlined,
                size: 16,
                color: isExcel ? AppColors.success : AppColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${FileHelper.formatBytes(file.fileSize)} • ${file.totalRows} satır',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 48, color: AppColors.textMuted.withAlpha(100)),
          const SizedBox(height: 14),
          Text(
            'Tablo Yok',
            style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Başlamak için dosya yükleyin.',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(TableSchema table) {
    final dateStr = table.lastAccessedAt != null
        ? DateFormat('dd.MM.yyyy').format(table.lastAccessedAt!)
        : (table.createdAt != null ? DateFormat('dd.MM.yyyy').format(table.createdAt!) : '');

    final queryState = ref.watch(queryProvider);
    final hasStarredQueries = queryState.savedQueries.any((q) => q.tableName == table.name && q.isFavorite);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showTableDetailsAndQueriesSheet(context, table),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                table.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (hasStarredQueries) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${table.rowCount} satır${dateStr.isNotEmpty ? '  •  $dateStr' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(tablesProvider.notifier).dropTable(table.name),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted.withAlpha(160)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(tablesProvider.notifier).markTableAccessed(table.name);
              widget.onNavigateToSql(table.name);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Sorgula',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTableDetailsAndQueriesSheet(BuildContext context, TableSchema table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final qState = ref.watch(queryProvider);
          final tableQueries = qState.savedQueries.where((q) => q.tableName == table.name).toList();

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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.table_chart_rounded, color: AppColors.accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                table.name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${table.rowCount} satır • ${table.columns.length} sütun',
                                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(ctx),
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
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Sütunlar
                      Text(
                        'Sütunlar (${table.columns.length})',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: table.columns.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.name,
                                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  c.type,
                                  style: GoogleFonts.firaCode(fontSize: 10, color: AppColors.accent),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      // Tabloya Özel Sorgular
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tabloya Özel Sorgular (${tableQueries.length})',
                            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                          if (tableQueries.isNotEmpty)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => ref.read(queryProvider.notifier).clearHistory(tableName: table.name),
                              child: Text(
                                'Temizle',
                                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (tableQueries.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Center(
                            child: Text(
                              'Bu tablo için henüz kaydedilmiş sorgu yok.',
                              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ),
                        )
                      else
                        ...tableQueries.map((q) => _buildTableQueryItem(ctx, q, table.name)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(tablesProvider.notifier).markTableAccessed(table.name);
                        widget.onNavigateToSql(table.name);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                      label: Text(
                        'Bu Tabloyu Sorgula',
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableQueryItem(BuildContext context, SavedQuery query, String tableName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(queryProvider.notifier).toggleFavorite(query.id),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    query.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: query.isFavorite ? AppColors.warning : AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SelectableText(
                  query.queryText,
                  style: GoogleFonts.firaCode(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(queryProvider.notifier).deleteQuery(query.id),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted.withAlpha(150)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (query.rowCount > 0) ...[
                Text(
                  '${query.rowCount} satır',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                DateFormat('dd.MM HH:mm').format(query.executedAt),
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: query.queryText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kopyalandı', style: GoogleFonts.dmSans()),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppColors.cardMuted, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.copy_rounded, size: 13, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(tablesProvider.notifier).markTableAccessed(tableName);
                  ref.read(queryProvider.notifier).setSql(query.queryText);
                  ref.read(queryProvider.notifier).runQuery(query.queryText, tableName);
                  widget.onNavigateToSql(tableName);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 3),
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

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Tümünü Temizle', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          'Tüm tablolar silinecektir. Emin misiniz?',
          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tablesProvider.notifier).clearAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Sil', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
