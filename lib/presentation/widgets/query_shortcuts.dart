import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class QueryShortcuts extends StatelessWidget {
  final void Function(String text, bool replace) onInsert;
  final List<String> availableTables;

  const QueryShortcuts({
    super.key,
    required this.onInsert,
    required this.availableTables,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          if (availableTables.isNotEmpty)
            _buildActionChip(
              label: 'SELECT *',
              onTap: () => onInsert('SELECT * FROM ${availableTables.first} LIMIT 50;', true),
            ),
          if (availableTables.isNotEmpty)
            _buildActionChip(
              label: 'COUNT',
              onTap: () => onInsert('SELECT COUNT(*) AS toplam FROM ${availableTables.first};', true),
            ),
          _buildChip('WHERE'),
          _buildChip('ORDER BY'),
          _buildChip('GROUP BY'),
          _buildChip('LIMIT 20'),
          _buildChip('COUNT(*)'),
          _buildChip('SUM()'),
          _buildChip('AVG()'),
          _buildChip('DISTINCT'),
          _buildChip('LIKE %'),
        ],
      ),
    );
  }

  Widget _buildChip(String keyword) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onInsert(' $keyword ', false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 1)),
            ],
          ),
          child: Text(
            keyword,
            style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
