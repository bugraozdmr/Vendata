import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/export_helper.dart';
import '../../domain/models/query_result.dart';
import '../widgets/data_grid_table.dart';

class FullscreenTableScreen extends StatefulWidget {
  final QueryResult result;
  final String? tableName;

  const FullscreenTableScreen({
    super.key,
    required this.result,
    this.tableName,
  });

  @override
  State<FullscreenTableScreen> createState() => _FullscreenTableScreenState();
}

class _FullscreenTableScreenState extends State<FullscreenTableScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Control Bar
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isLandscape ? 8 : 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.cardMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fullscreen_exit_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.tableName ?? 'Sonuç Tablosu',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: isLandscape ? 14 : 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.result.rowCount} satır  •  ${widget.result.columns.length} sütun  •  ${widget.result.executionTimeMs} ms',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _isExporting
                        ? null
                        : () async {
                            setState(() => _isExporting = true);
                            try {
                              await ExportHelper.shareAsExcel(widget.result);
                            } finally {
                              if (mounted) setState(() => _isExporting = false);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.successWash,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.success,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.download_rounded, size: 16, color: AppColors.success),
                                const SizedBox(width: 6),
                                Text(
                                  'Excel İndir',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Fullscreen Data Table View
            Expanded(
              child: DataGridTable(result: widget.result),
            ),
          ],
        ),
      ),
    );
  }
}

