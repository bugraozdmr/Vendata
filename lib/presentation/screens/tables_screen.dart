import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../domain/models/recent_file.dart';
import '../../domain/models/saved_query.dart';
import '../../domain/models/table_schema.dart';
import '../providers/connection_provider.dart';
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
    final connectionsState = ref.watch(connectionsProvider);
    final activeConnection = connectionsState.activeConnection;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, isLandscape ? 24 : 100),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF15161A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppConfig.appName,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: tablesState.isLoading
                      ? null
                      : () => ref.read(tablesProvider.notifier).refreshTables(),
                  behavior: HitTestBehavior.opaque,
                  child: Tooltip(
                    message: 'Tabloları yenile',
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                if (!tablesState.isRemote) const SizedBox(width: 8),
                if (!tablesState.isRemote)
                  GestureDetector(
                    onTap: tablesState.isLoading ? null : _pickFile,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: tablesState.isLoading ? AppColors.textMuted : AppColors.accent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: tablesState.isLoading
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.accent.withAlpha(45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tablesState.isLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          else ...[
                            const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Dosya Ekle',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (tablesState.isRemote) ...[
              const SizedBox(height: 14),
              _buildRemoteBanner(
                tablesState,
                activeConnection == null
                    ? const ConnectionHealth()
                    : connectionsState.healthFor(activeConnection.id),
              ),
            ],
            if (tablesState.isLoading) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.accent.withAlpha(60), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withAlpha(18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İşlem Yapılıyor...',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dosya işleniyor ve SQLite tabloları güncelleniyor',
                            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (tablesState.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorBanner(tablesState.errorMessage!),
            ],
            if (tablesState.recentFiles.isNotEmpty) ...[
              const SizedBox(height: 22),
              _buildRecentFiles(tablesState.recentFiles),
            ],
            const SizedBox(height: 24),
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

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(error, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteBanner(TablesState tablesState, ConnectionHealth health) {
    final healthColor = _healthColor(health);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: health.isOffline ? AppColors.errorWash : AppColors.successWash,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: healthColor.withAlpha(60), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.dns_rounded, size: 18, color: healthColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  health.isOffline ? 'Uzak bağlantı koptu' : 'Uzak bağlantı aktif',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: healthColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${tablesState.connectionLabel} · ${_healthLabel(health)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: health.isOffline ? AppColors.error : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(connectionsProvider.notifier).disconnect();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_off_rounded, size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    'Kes',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _healthColor(ConnectionHealth health) {
    switch (health.status) {
      case ConnectionHealthStatus.online:
        return AppColors.success;
      case ConnectionHealthStatus.offline:
        return AppColors.error;
      case ConnectionHealthStatus.checking:
        return AppColors.accent;
      case ConnectionHealthStatus.unknown:
        return AppColors.textMuted;
    }
  }

  String _healthLabel(ConnectionHealth health) {
    switch (health.status) {
      case ConnectionHealthStatus.online:
        return 'Çevrimiçi';
      case ConnectionHealthStatus.offline:
        return 'Erişilemiyor';
      case ConnectionHealthStatus.checking:
        return 'Kontrol ediliyor...';
      case ConnectionHealthStatus.unknown:
        return 'Bilinmiyor';
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
            'Henüz Tablo Eklenmedi',
            style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Başlamak için sağ üstteki butondan veya aşağıdan Excel, CSV ya da SQL dosyanızı seçin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Dosya Seç',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          color: AppColors.surface,
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

  Widget _buildTableCard(TableSchema table) {
    final dateStr = table.lastAccessedAt != null
        ? DateFormat('dd.MM.yyyy').format(table.lastAccessedAt!)
        : (table.createdAt != null ? DateFormat('dd.MM.yyyy').format(table.createdAt!) : '');

    final queryState = ref.watch(queryProvider);
    final isRemote = ref.watch(tablesProvider).isRemote;
    final hasStarredQueries = queryState.savedQueries.any((q) => q.tableName == table.name && q.isFavorite);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                    child: Icon(Icons.table_chart_rounded, color: AppColors.textPrimary, size: 20),
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
                              Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
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
          if (!isRemote) ...[
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(tablesProvider.notifier).dropTable(table.name),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted.withAlpha(160)),
              ),
            ),
          ],
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
            decoration: BoxDecoration(
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
                            child: Icon(Icons.table_chart_rounded, color: AppColors.accent, size: 22),
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
                          child: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
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
                              color: AppColors.surface,
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
                            color: AppColors.surface,
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
                    color: AppColors.surface,
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
        color: AppColors.surface,
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
                  child: Icon(Icons.copy_rounded, size: 13, color: AppColors.textSecondary),
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
}
