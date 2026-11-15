import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/query_result.dart';

class DataGridTable extends StatefulWidget {
  final QueryResult result;

  const DataGridTable({
    super.key,
    required this.result,
  });

  @override
  State<DataGridTable> createState() => _DataGridTableState();
}

class _DataGridTableState extends State<DataGridTable> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String _filterText = '';
  int? _selectedRow;
  int? _selectedCol;

  final TextEditingController _filterController = TextEditingController();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _filterController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result.columns.isEmpty) {
      return Center(
        child: Text(
          'Görüntülenecek veri bulunamadı.',
          style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final filteredRows = _getFilteredAndSortedRows();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _filterController,
                    onChanged: (val) => setState(() => _filterText = val.trim()),
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tabloda ara...',
                      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                      suffixIcon: _filterText.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                              onPressed: () {
                                _filterController.clear();
                                setState(() => _filterText = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${filteredRows.length}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              child: Scrollbar(
                controller: _horizontalController,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: DataTable(
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    headingRowHeight: 44,
                    dataRowMinHeight: 42,
                    dataRowMaxHeight: 48,
                    headingRowColor: WidgetStateProperty.all(AppColors.cardMuted),
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    columns: List.generate(widget.result.columns.length, (index) {
                      final col = widget.result.columns[index];
                      return DataColumn(
                        label: Text(
                          col,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        onSort: (columnIndex, ascending) {
                          setState(() {
                            _sortColumnIndex = columnIndex;
                            _sortAscending = ascending;
                          });
                        },
                      );
                    }),
                    rows: List.generate(filteredRows.length, (rowIndex) {
                      final row = filteredRows[rowIndex];
                      final isEven = rowIndex % 2 == 0;

                      return DataRow(
                        color: WidgetStateProperty.all(
                          isEven ? AppColors.surface : AppColors.background.withAlpha(120),
                        ),
                        cells: List.generate(widget.result.columns.length, (colIndex) {
                          final val = colIndex < row.length ? row[colIndex] : null;
                          final isNull = val == null;
                          final isNumber = val is num;
                          final fullText = isNull ? '—' : val.toString();
                          final displayText = fullText.length > 25 ? '${fullText.substring(0, 22)}...' : fullText;
                          final isSelected = _selectedRow == rowIndex && _selectedCol == colIndex;
                          final coordinateLabel = '${rowIndex + 1}x${colIndex + 1}';
                          final colName = widget.result.columns[colIndex];

                          return DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: isSelected
                                  ? BoxDecoration(
                                      color: AppColors.accent.withAlpha(30),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.accent, width: 1.5),
                                    )
                                  : null,
                              child: Tooltip(
                                message: '$coordinateLabel: $fullText',
                                waitDuration: const Duration(milliseconds: 300),
                                child: Align(
                                  alignment: isNumber ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Text(
                                    displayText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: isNull
                                          ? AppColors.textMuted
                                          : (isNumber ? AppColors.accent : AppColors.textPrimary),
                                      fontWeight: isNumber || isSelected ? FontWeight.w600 : FontWeight.w400,
                                      fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            onTap: () {
                              _showCellInspectionSheet(
                                context: context,
                                row: row,
                                rowIndex: rowIndex,
                                colIndex: colIndex,
                                rawValue: val,
                                colName: colName,
                              );
                            },
                            onLongPress: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _selectedRow = rowIndex;
                                _selectedCol = colIndex;
                              });
                              Clipboard.setData(ClipboardData(text: isNull ? '' : fullText));
                              _showFeedback(context, 'Hücre ($coordinateLabel) kopyalandı: $displayText');
                            },
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCellInspectionSheet({
    required BuildContext context,
    required List<dynamic> row,
    required int rowIndex,
    required int colIndex,
    required dynamic rawValue,
    required String colName,
  }) {
    setState(() {
      _selectedRow = rowIndex;
      _selectedCol = colIndex;
    });

    final isNull = rawValue == null;
    final String typeName = isNull
        ? 'NULL'
        : (rawValue is int
            ? 'INTEGER'
            : (rawValue is double
                ? 'REAL'
                : (rawValue is bool ? 'BOOLEAN' : 'TEXT')));

    final String fullText = isNull ? '' : rawValue.toString();
    final String coordinateLabel = '${rowIndex + 1}x${colIndex + 1}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header: Coordinate, Col name, Type Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                coordinateLabel,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Satır ${rowIndex + 1}',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          colName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      typeName,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Full content area (no truncation)
              Container(
                constraints: const BoxConstraints(maxHeight: 220, minHeight: 64),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SelectableText(
                    isNull ? 'NULL (Değer yok)' : (fullText.isEmpty ? '(Boş metin)' : fullText),
                    style: isNull || fullText.isEmpty
                        ? GoogleFonts.dmSans(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                          )
                        : GoogleFonts.firaCode(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons: Kopyala, Paylaş
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: fullText));
                        Navigator.pop(ctx);
                        _showFeedback(context, 'Hücre değeri ($coordinateLabel) kopyalandı.');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Değeri Kopyala',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        SharePlus.instance.share(
                          ShareParams(
                            text: fullText,
                            subject: '$colName [$coordinateLabel]',
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share_rounded, size: 16, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              'Paylaş',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Copy entire row
              GestureDetector(
                onTap: () {
                  final rowStr = _formatRowAsString(row);
                  Clipboard.setData(ClipboardData(text: rowStr));
                  Navigator.pop(ctx);
                  _showFeedback(context, 'Satır ${rowIndex + 1} panoya kopyalandı.');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_rows_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Tüm Satırı Kopyala (${widget.result.columns.length} Sütun)',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRowAsString(List<dynamic> row) {
    final buffer = StringBuffer();
    for (var i = 0; i < widget.result.columns.length; i++) {
      final col = widget.result.columns[i];
      final val = i < row.length ? row[i] : null;
      buffer.writeln('$col: ${val ?? "NULL"}');
    }
    return buffer.toString().trim();
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<List<dynamic>> _getFilteredAndSortedRows() {
    var rows = List<List<dynamic>>.from(widget.result.rows);

    if (_filterText.isNotEmpty) {
      final query = _filterText.toLowerCase();
      rows = rows.where((row) {
        return row.any((cell) => cell?.toString().toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_sortColumnIndex != null && _sortColumnIndex! < widget.result.columns.length) {
      final idx = _sortColumnIndex!;
      rows.sort((a, b) {
        final valA = idx < a.length ? a[idx] : null;
        final valB = idx < b.length ? b[idx] : null;

        if (valA == null && valB == null) return 0;
        if (valA == null) return _sortAscending ? -1 : 1;
        if (valB == null) return _sortAscending ? 1 : -1;

        if (valA is num && valB is num) {
          return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
        }

        return _sortAscending
            ? valA.toString().compareTo(valB.toString())
            : valB.toString().compareTo(valA.toString());
      });
    }

    return rows;
  }
}
