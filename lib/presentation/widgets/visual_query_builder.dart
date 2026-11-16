import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/table_schema.dart';
import '../../domain/models/visual_query.dart';

class VisualQueryBuilder extends StatefulWidget {
  final List<TableSchema> tables;
  final String? initialTable;
  final VisualQuery? initialQuery;
  final bool isExecuting;
  final void Function(String sql) onExecute;
  final ValueChanged<String>? onTableChanged;
  final ValueChanged<VisualQuery>? onQueryChanged;
  final List<String> joinTypes;

  const VisualQueryBuilder({
    super.key,
    required this.tables,
    this.initialTable,
    this.initialQuery,
    this.isExecuting = false,
    required this.onExecute,
    this.onTableChanged,
    this.onQueryChanged,
    this.joinTypes = const [
      'LEFT JOIN',
      'INNER JOIN',
      'RIGHT JOIN',
      'FULL OUTER JOIN',
      'CROSS JOIN',
    ],
  });

  @override
  State<VisualQueryBuilder> createState() => _VisualQueryBuilderState();
}

class _VisualQueryBuilderState extends State<VisualQueryBuilder> {
  late VisualQuery _query;
  int _activeSubTab = 0; // 0: Sütun & Filtre, 1: Grupla, 2: Hesapla, 3: JOIN

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _query = widget.initialQuery!.copy();
      if (widget.initialTable != null &&
          widget.initialTable!.isNotEmpty &&
          _query.selectedTable.isEmpty) {
        _query.selectedTable = widget.initialTable!;
      }
    } else {
      final defaultTable = widget.initialTable ?? '';
      _query = VisualQuery(selectedTable: defaultTable);
    }
  }

  void _notify() {
    widget.onQueryChanged?.call(_query.copy());
  }

  @override
  void didUpdateWidget(covariant VisualQueryBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTable != oldWidget.initialTable &&
        widget.initialTable != null &&
        widget.initialTable!.isNotEmpty &&
        widget.initialTable != _query.selectedTable) {
      setState(() {
        _query.selectedTable = widget.initialTable!;
        _query.selectedColumns = [];
        _query.filters = [];
        _query.groupByColumns = [];
        _query.aggregates = [];
        _query.orders = [];
        _query.calculatedFields = [];
        _query.joinConfig = null;
      });
      _notify();
    }
  }

  TableSchema? get _currentTableSchema {
    if (_query.selectedTable.isEmpty) return null;
    try {
      return widget.tables.firstWhere((t) => t.name == _query.selectedTable);
    } catch (_) {
      return null;
    }
  }

  List<String> get _availableColumns {
    return _currentTableSchema?.columnNames ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (widget.tables.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Center(
          child: Text(
            'Henüz tablo eklenmedi.\nÖnce Veriler sekmesinden dosya yükleyin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13, height: 1.4),
          ),
        ),
      );
    }

    final currentSql = _query.toSql();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-navigation pills (wrap aligned to left so it matches the rest of the UI)
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSubNavPill(0, 'Sütun & Filtre', Icons.filter_list_rounded),
              _buildSubNavPill(1, 'Grupla & Özet', Icons.pie_chart_rounded),
              _buildSubNavPill(2, 'Hesapla', Icons.functions_rounded),
              _buildSubNavPill(3, 'JOIN', Icons.alt_route_rounded),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Active module content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: isLandscape ? 24 : 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_activeSubTab == 0) _buildFilterAndColumnsModule(),
                if (_activeSubTab == 1) _buildGroupingAndAggregationModule(),
                if (_activeSubTab == 2) _buildCalculatedFieldsModule(),
                if (_activeSubTab == 3) _buildJoinModule(),
                const SizedBox(height: 14),
                _buildSqlPreviewCard(currentSql),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: (currentSql.isEmpty || widget.isExecuting)
                        ? null
                        : () {
                            _notify();
                            widget.onExecute(currentSql);
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: (currentSql.isEmpty || widget.isExecuting) ? AppColors.textMuted : AppColors.accent,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: (currentSql.isEmpty || widget.isExecuting)
                            ? null
                            : [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Center(
                        child: widget.isExecuting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sorguyu Çalıştır',
                                    style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubNavPill(int index, String label, IconData icon) {
    final isSelected = _activeSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeSubTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withAlpha(30), blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
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

  Widget _buildTableSelectCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
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
                child: Icon(Icons.table_chart_rounded, size: 22, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tablo Seçiniz',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'İşlem yapacağınız tabloyu belirleyin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Yüklü Tablolar:',
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tables.map((table) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _query.selectedTable = table.name;
                    _query.selectedColumns = [];
                    _query.filters = [];
                    _query.groupByColumns = [];
                    _query.aggregates = [];
                    _query.orders = [];
                  });
                  widget.onTableChanged?.call(table.name);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_rows_rounded, size: 16, color: AppColors.textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        table.name,
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${table.rowCount} satır)',
                        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // MODULE 1: Sütun Seçimi, DISTINCT, Çoklu Filtreler, Sıralama, Limit & Sayfalama
  Widget _buildFilterAndColumnsModule() {
    if (_query.selectedTable.isEmpty) {
      return _buildTableSelectCard();
    }

    return Column(
      children: [
        _buildCard(
          title: 'Tablo & Sütunlar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown<String>(
                      label: 'Kaynak Tablo',
                      value: _query.selectedTable.isEmpty ? null : _query.selectedTable,
                      hint: 'Tablo Seçiniz...',
                      items: widget.tables.map((t) => t.name).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _query.selectedTable = val;
                            _query.selectedColumns = [];
                            _query.filters = [];
                            _query.groupByColumns = [];
                            _query.aggregates = [];
                            _query.orders = [];
                          });
                          _notify();
                          widget.onTableChanged?.call(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DISTINCT', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() => _query.isDistinct = !_query.isDistinct);
                          _notify();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _query.isDistinct ? AppColors.accent : AppColors.cardMuted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Tekilleştir',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _query.isDistinct ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Görüntülenecek Sütunlar', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _query.selectedColumns = []);
                      _notify();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _query.selectedColumns.isEmpty ? AppColors.primary : AppColors.cardMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Tümü (*)',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _query.selectedColumns.isEmpty ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  ..._availableColumns.map((col) {
                    final isSelected = _query.selectedColumns.contains(col);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          final list = List<String>.from(_query.selectedColumns);
                          if (isSelected) {
                            list.remove(col);
                          } else {
                            list.add(col);
                          }
                          _query.selectedColumns = list;
                        });
                        _notify();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accent : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
                        ),
                        child: Text(
                          col,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Filtreleme (WHERE)
        _buildCard(
          title: 'Filtreler (WHERE)',
          action: GestureDetector(
            onTap: () {
              if (_availableColumns.isNotEmpty) {
                setState(() {
                  _query.filters.add(
                    QueryFilter(
                      column: _availableColumns.first,
                      operator: '=',
                      value: '',
                      combinator: 'AND',
                    ),
                  );
                });
                _notify();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text('Filtre Ekle', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ],
              ),
            ),
          ),
          child: _query.filters.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('Filtre yok (tüm kayıtlar listelenir).', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
                )
              : Column(
                  children: List.generate(_query.filters.length, (idx) {
                    final filter = _query.filters[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cardMuted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (idx > 0) ...[
                                Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: filter.combinator,
                                      style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
                                      items: const [
                                        DropdownMenuItem(value: 'AND', child: Text('VE')),
                                        DropdownMenuItem(value: 'OR', child: Text('VEYA')),
                                      ],
                                      onChanged: (v) {
                                        setState(() => filter.combinator = v ?? 'AND');
                                        _notify();
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                flex: 4,
                                child: _buildMiniDropdown(
                                  value: filter.column,
                                  items: _availableColumns,
                                  onChanged: (v) {
                                    setState(() => filter.column = v ?? filter.column);
                                    _notify();
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: _buildMiniDropdown(
                                  value: filter.operator,
                                  items: const ['=', '!=', '>', '<', '>=', '<=', 'LIKE', 'STARTS WITH', 'ENDS WITH', 'IS NULL', 'IS NOT NULL'],
                                  onChanged: (v) {
                                    setState(() => filter.operator = v ?? filter.operator);
                                    _notify();
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () {
                                  setState(() => _query.filters.removeAt(idx));
                                  _notify();
                                },
                              ),
                            ],
                          ),
                          if (filter.operator != 'IS NULL' && filter.operator != 'IS NOT NULL') ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 36,
                              child: TextFormField(
                                initialValue: filter.value,
                                onChanged: (v) {
                                  filter.value = v;
                                  _notify();
                                },
                                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: filter.operator.contains('LIKE') ? 'Arama metni...' : 'Değer...',
                                  hintStyle: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ),
        ),
        const SizedBox(height: 12),

        // Sıralama & Limit
        _buildCard(
          title: 'Sıralama & Limit',
          action: GestureDetector(
            onTap: () {
              if (_availableColumns.isNotEmpty) {
                setState(() {
                  _query.orders.add(QueryOrder(column: _availableColumns.first, ascending: true));
                });
                _notify();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryWash,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: AppColors.textPrimary),
                  const SizedBox(width: 4),
                  Text('Sırala', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_query.orders.isNotEmpty) ...[
                ...List.generate(_query.orders.length, (idx) {
                  final order = _query.orders[idx];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMiniDropdown(
                            value: order.column,
                            items: _availableColumns,
                            onChanged: (v) {
                              setState(() => order.column = v ?? order.column);
                              _notify();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() => order.ascending = !order.ascending);
                            _notify();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: order.ascending ? AppColors.accentLight : AppColors.cardMuted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              order.ascending ? 'Artan (A-Z)' : 'Azalan (Z-A)',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: order.ascending ? AppColors.accent : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () {
                            setState(() => _query.orders.removeAt(idx));
                            _notify();
                          },
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Limit', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        _buildMiniDropdown(
                          value: _query.limit.toString(),
                          items: const ['10', '25', '50', '100', '500', '1000'],
                          onChanged: (v) {
                            setState(() => _query.limit = int.tryParse(v ?? '50') ?? 50);
                            _notify();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Başlangıç (Offset)', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: _query.offset >= _query.limit
                                  ? () {
                                      setState(() => _query.offset -= _query.limit);
                                      _notify();
                                    }
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                '${_query.offset}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                setState(() => _query.offset += _query.limit);
                                _notify();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // MODULE 2: Gruplama (GROUP BY) & Özet
  Widget _buildGroupingAndAggregationModule() {
    if (_query.selectedTable.isEmpty) {
      return _buildTableSelectCard();
    }
    return Column(
      children: [
        _buildCard(
          title: 'Gruplama (GROUP BY)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kategori seçin:', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableColumns.map((col) {
                  final isSelected = _query.groupByColumns.contains(col);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        final list = List<String>.from(_query.groupByColumns);
                        if (isSelected) {
                          list.remove(col);
                        } else {
                          list.add(col);
                        }
                        _query.groupByColumns = list;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.cardMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        col,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Agregasyonlar
        _buildCard(
          title: 'İstatistik & Özet Hesaplar',
          action: GestureDetector(
            onTap: () {
              setState(() {
                _query.aggregates.add(
                  AggregateMetric(
                    func: AggregateFunc.count,
                    column: _availableColumns.isNotEmpty ? _availableColumns.first : '*',
                  ),
                );
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text('Metrik Ekle', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ],
              ),
            ),
          ),
          child: _query.aggregates.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('COUNT, SUM, AVG gibi metrik ekleyin.', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
                )
              : Column(
                  children: List.generate(_query.aggregates.length, (idx) {
                    final agg = _query.aggregates[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.cardMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildMiniDropdown(
                              value: agg.func.name.toUpperCase(),
                              items: const ['COUNT', 'SUM', 'AVG', 'MIN', 'MAX'],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    agg.func = AggregateFunc.values.firstWhere((f) => f.name.toUpperCase() == v);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 4,
                            child: _buildMiniDropdown(
                              value: agg.column ?? '*',
                              items: ['*', ..._availableColumns],
                              onChanged: (v) => setState(() => agg.column = v),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => setState(() => _query.aggregates.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ),
        const SizedBox(height: 12),

        // HAVING Filtresi
        _buildCard(
          title: 'Grup Filtresi (HAVING)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Örn: SUM(fiyat) > 1000', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: TextFormField(
                  initialValue: _query.havingClause ?? '',
                  onChanged: (v) => setState(() => _query.havingClause = v.trim().isEmpty ? null : v.trim()),
                  style: GoogleFonts.firaCode(fontSize: 12, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'HAVING koşulu...',
                    hintStyle: GoogleFonts.firaCode(fontSize: 12, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.cardMuted,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // MODULE 3: Hesaplanmış Sütunlar
  Widget _buildCalculatedFieldsModule() {
    if (_query.selectedTable.isEmpty) {
      return _buildTableSelectCard();
    }
    return Column(
      children: [
        _buildCard(
          title: 'Hızlı Şablonlar',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTemplateChip(
                label: 'KDV (%20)',
                expr: _availableColumns.isNotEmpty ? '${_availableColumns.first} * 1.20' : 'fiyat * 1.20',
                alias: 'kdvli',
              ),
              _buildTemplateChip(
                label: 'Büyük Harf',
                expr: _availableColumns.isNotEmpty ? 'UPPER(${_availableColumns.first})' : 'UPPER(isim)',
                alias: 'buyuk',
              ),
              _buildTemplateChip(
                label: 'Yıl (YYYY)',
                expr: _availableColumns.isNotEmpty ? "strftime('%Y', ${_availableColumns.first})" : "strftime('%Y', tarih)",
                alias: 'yil',
              ),
              _buildTemplateChip(
                label: 'Tam Sayı',
                expr: _availableColumns.isNotEmpty ? 'CAST(${_availableColumns.first} AS INTEGER)' : 'CAST(col AS INTEGER)',
                alias: 'tamsayi',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildCard(
          title: 'Formüller',
          action: GestureDetector(
            onTap: () {
              setState(() {
                _query.calculatedFields.add(
                  CalculatedField(
                    expression: _availableColumns.isNotEmpty ? '${_availableColumns.first} * 2' : 'col * 2',
                    alias: 'sutun_${_query.calculatedFields.length + 1}',
                  ),
                );
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text('Formül Ekle', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ],
              ),
            ),
          ),
          child: _query.calculatedFields.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Özel formül veya hesaplama ekleyin.', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
                )
              : Column(
                  children: List.generate(_query.calculatedFields.length, (idx) {
                    final calc = _query.calculatedFields[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cardMuted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: SizedBox(
                              height: 36,
                              child: TextFormField(
                                initialValue: calc.expression,
                                onChanged: (v) => calc.expression = v,
                                style: GoogleFonts.firaCode(fontSize: 12, color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 36,
                              child: TextFormField(
                                initialValue: calc.alias,
                                onChanged: (v) => calc.alias = v,
                                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => setState(() => _query.calculatedFields.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }

  // MODULE 4: Tablo Birleştirme (JOIN)
  Widget _buildJoinModule() {
    if (_query.selectedTable.isEmpty) {
      return _buildTableSelectCard();
    }
    final otherTables = widget.tables.where((t) => t.name != _query.selectedTable).toList();

    if (otherTables.isEmpty) {
      return _buildCard(
        title: 'Tablo Birleştir (JOIN)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.alt_route_rounded, size: 34, color: AppColors.textMuted.withAlpha(140)),
            const SizedBox(height: 10),
            Text(
              'JOIN için en az iki tablo gerekir.',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Veriler sekmesinden ikinci bir tablo veya dosya yükleyin; '
              'ardından buradan tabloları birleştirebilirsiniz.',
              style: GoogleFonts.dmSans(fontSize: 12, height: 1.4, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return _buildCard(
      title: 'Tablo Birleştir (JOIN)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('JOIN Bağlantısı', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Switch(
                value: _query.joinConfig != null,
                activeThumbColor: AppColors.accent,
                onChanged: (val) {
                  setState(() {
                    if (!val) {
                      _query.joinConfig = null;
                    } else if (otherTables.isNotEmpty) {
                      final target = otherTables.first;
                      _query.joinConfig = JoinConfig(
                        type: 'LEFT JOIN',
                        table: target.name,
                        leftCol: _availableColumns.isNotEmpty ? _availableColumns.first : '',
                        rightCol: target.columnNames.isNotEmpty ? target.columnNames.first : '',
                      );
                    }
                  });
                },
              ),
            ],
          ),
          if (_query.joinConfig != null && otherTables.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMiniDropdown(
                    label: 'Tür',
                    value: _query.joinConfig!.type,
                    items: widget.joinTypes.contains(_query.joinConfig!.type)
                        ? widget.joinTypes
                        : [...widget.joinTypes, _query.joinConfig!.type],
                    onChanged: (v) => setState(() => _query.joinConfig!.type = v ?? widget.joinTypes.first),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniDropdown(
                    label: 'Hedef Tablo',
                    value: _query.joinConfig!.table,
                    items: otherTables.map((t) => t.name).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _query.joinConfig!.table = v;
                          final match = otherTables.firstWhere((t) => t.name == v);
                          if (match.columnNames.isNotEmpty) {
                            _query.joinConfig!.rightCol = match.columnNames.first;
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_query.joinConfig!.type == 'CROSS JOIN')
              Text(
                'CROSS JOIN tüm satırları birbiriyle eşleştirir (kartezyen çarpım); '
                'ON koşulu kullanılmaz.',
                style: GoogleFonts.dmSans(fontSize: 12, height: 1.4, color: AppColors.textMuted),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildMiniDropdown(
                      label: '${_query.selectedTable} sütunu',
                      value: _query.joinConfig!.leftCol,
                      items: _availableColumns,
                      onChanged: (v) => setState(() => _query.joinConfig!.leftCol = v ?? ''),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('=', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Expanded(
                    child: _buildMiniDropdown(
                      label: '${_query.joinConfig!.table} sütunu',
                      value: _query.joinConfig!.rightCol,
                      items: otherTables.firstWhere((t) => t.name == _query.joinConfig!.table, orElse: () => otherTables.first).columnNames,
                      onChanged: (v) => setState(() => _query.joinConfig!.rightCol = v ?? ''),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateChip({required String label, required String expr, required String alias}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _query.calculatedFields.add(CalculatedField(expression: expr, alias: alias));
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
      ),
    );
  }

  Widget _buildSqlPreviewCard(String currentSql) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SQL Önizleme',
                style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: currentSql));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('SQL panoya kopyalandı.', style: GoogleFonts.dmSans()),
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
                  child: Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            currentSql,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: AppColors.codeText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, Widget? action, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    String? hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.cardMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: items.contains(value) ? value : null,
              hint: hint != null ? Text(hint, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)) : null,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
              items: items.map((item) {
                return DropdownMenuItem<T>(value: item, child: Text(item.toString(), overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniDropdown({
    String? label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
        ],
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textSecondary),
              items: items.map((col) {
                return DropdownMenuItem(value: col, child: Text(col, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
