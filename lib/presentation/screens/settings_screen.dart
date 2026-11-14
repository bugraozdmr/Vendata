import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../domain/models/saved_query.dart';
import '../providers/database_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final void Function(String sql) onOpenQuery;

  const SettingsScreen({super.key, required this.onOpenQuery});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showAllHistory = false;
  int _historyFilter = 0; // 0: Tümü, 1: Yıldızlılar

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(databaseEngineProvider);
    final tablesState = ref.watch(tablesProvider);
    final queryState = ref.watch(queryProvider);

    final dbSizeBytes = engine.getDatabaseSizeBytes();
    final totalTables = tablesState.tables.length;
    final totalRows = tablesState.tables.fold<int>(0, (sum, t) => sum + t.rowCount);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'Ayarlar',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 20),
            _buildStorageSection(dbSizeBytes, totalTables, totalRows),
            const SizedBox(height: 28),
            _buildQueryHistory(queryState),
            const SizedBox(height: 28),
            _buildDangerZone(),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageSection(int bytes, int tables, int rows) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storage_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Depolama',
                style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildStatCard(FileHelper.formatBytes(bytes), 'Boyut', AppColors.accent),
              const SizedBox(width: 10),
              _buildStatCard('$tables', 'Tablo', AppColors.success),
              const SizedBox(width: 10),
              _buildStatCard('$rows', 'Satır', AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueryHistory(QueryState queryState) {
    var history = queryState.savedQueries;
    final totalCount = history.length;
    final favoriteCount = history.where((q) => q.isFavorite).length;

    if (_historyFilter == 1) {
      history = history.where((q) => q.isFavorite).toList();
    }

    final displayedHistory = _showAllHistory ? history : history.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sorgu Geçmişi',
              style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
            ),
            const Spacer(),
            if (history.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(queryProvider.notifier).clearHistory(),
                child: Text('Temizle', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Filter pills: Tümü / Yıldızlılar
        Row(
          children: [
            _buildHistoryFilterPill(0, 'Tümü ($totalCount)', Icons.history_rounded),
            const SizedBox(width: 8),
            _buildHistoryFilterPill(1, 'Yıldızlılar ($favoriteCount)', Icons.star_rounded),
          ],
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Center(
              child: Text(
                _historyFilter == 1 ? 'Yıldızlı sorgu bulunamadı.' : 'Henüz sorgu çalıştırılmadı.',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          )
        else ...[
          ...displayedHistory.map((q) => _buildHistoryItem(q)),
          if (history.length > 4) ...[
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showAllHistory = !_showAllHistory),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showAllHistory ? 'Daha Az Göster' : 'Tümünü Göster (${history.length})',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAllHistory ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildHistoryFilterPill(int index, String label, IconData icon) {
    final isSelected = _historyFilter == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _historyFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withAlpha(25), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
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

  Widget _buildHistoryItem(SavedQuery query) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // ⭐ Star toggle
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(queryProvider.notifier).toggleFavorite(query.id),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                query.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: query.isFavorite ? AppColors.warning : AppColors.textMuted,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (query.tableName != null && query.tableName!.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      query.tableName!,
                      style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent),
                    ),
                  ),
                ],
                Text(
                  query.queryText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.firaCode(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Clipboard.setData(ClipboardData(text: query.queryText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kopyalandı', style: GoogleFonts.dmSans()),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cardMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onOpenQuery(query.queryText),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorWash,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sıfırla',
            style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.error),
          ),
          const SizedBox(height: 4),
          Text(
            'Tüm veriler ve geçmiş silinir.',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _confirmReset(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.error, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Verileri Temizle',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Sıfırla', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          'Tüm veriler silinecektir. Bu işlem geri alınamaz.',
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
              ref.read(queryProvider.notifier).clearHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tüm veriler temizlendi.', style: GoogleFonts.dmSans()),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
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
