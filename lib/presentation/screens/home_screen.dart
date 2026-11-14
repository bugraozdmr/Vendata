import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/database_provider.dart';
import 'settings_screen.dart';
import 'sql_screen.dart';
import 'tables_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  String? _selectedTableForQuery;

  void _navigateToQuery(String tableName) {
    setState(() {
      _selectedTableForQuery = tableName;
      _currentIndex = 1;
    });
  }

  void _openQueryFromHistory(String sql) {
    ref.read(queryProvider.notifier).setSql(sql);
    ref.read(queryProvider.notifier).runQuery(sql);
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TablesScreen(onNavigateToSql: _navigateToQuery),
      SqlScreen(targetTable: _selectedTableForQuery),
      SettingsScreen(onOpenQuery: _openQueryFromHistory),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildFloatingBottomNav(),
    );
  }

  Widget _buildFloatingBottomNav() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(54, 0, 54, 20),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(index: 0, icon: Icons.grid_view_rounded),
            _buildNavItem(index: 1, icon: Icons.terminal_rounded),
            _buildNavItem(index: 2, icon: Icons.tune_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 1 && _currentIndex != 1) {
          // Ortadaki nav butonuna basıldığında tablo otomatik seçilmesin, manuel seçilsin
          setState(() {
            _selectedTableForQuery = null;
            _currentIndex = 1;
          });
        } else {
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: isSelected ? 68 : 50,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: isSelected ? Colors.white : Colors.white.withAlpha(130),
          ),
        ),
      ),
    );
  }
}
