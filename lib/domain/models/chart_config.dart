enum ChartType { bar, line, pie }

class ChartConfig {
  final ChartType type;
  final String labelColumn;
  final String valueColumn;
  final int maxItems;

  const ChartConfig({
    required this.type,
    required this.labelColumn,
    required this.valueColumn,
    this.maxItems = 15,
  });

  ChartConfig copyWith({
    ChartType? type,
    String? labelColumn,
    String? valueColumn,
    int? maxItems,
  }) {
    return ChartConfig(
      type: type ?? this.type,
      labelColumn: labelColumn ?? this.labelColumn,
      valueColumn: valueColumn ?? this.valueColumn,
      maxItems: maxItems ?? this.maxItems,
    );
  }
}

