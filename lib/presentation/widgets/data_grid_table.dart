import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final TextEditingController _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
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
                    color: Colors.white,
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
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                      suffixIcon: _filterText.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
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
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: DataTable(
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  headingRowHeight: 44,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 46,
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
                        isEven ? Colors.white : AppColors.background.withAlpha(120),
                      ),
                      cells: List.generate(widget.result.columns.length, (colIndex) {
                        final val = colIndex < row.length ? row[colIndex] : null;
                        final isNull = val == null;
                        final isNumber = val is num;
                        final fullText = isNull ? '—' : val.toString();
                        final displayText = fullText.length > 25 ? '${fullText.substring(0, 22)}...' : fullText;

                        return DataCell(
                          Tooltip(
                            message: fullText,
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
                                  fontWeight: isNumber ? FontWeight.w600 : FontWeight.w400,
                                  fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                          ),
                          onTap: () {
                            if (fullText.length > 22) {
                              _showCellDetail(context, widget.result.columns[colIndex], fullText);
                            }
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
      ],
    );
  }

  void _showCellDetail(BuildContext context, String colName, String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(colName, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SelectableText(
          text,
          style: GoogleFonts.firaCode(fontSize: 13, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Kapat', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
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
