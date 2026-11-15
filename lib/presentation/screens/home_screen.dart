import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/database_provider.dart';
import 'connections_screen.dart';
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final pages = [
      TablesScreen(onNavigateToSql: _navigateToQuery),
      SqlScreen(targetTable: _selectedTableForQuery),
      ConnectionsScreen(onConnected: () => setState(() => _currentIndex = 0)),
      SettingsScreen(onOpenQuery: _openQueryFromHistory),
    ];

    if (isLandscape) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Row(
            children: [
              _buildSideNavRail(),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: pages,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildFloatingBottomNav(context),
    );
  }

  Widget _buildSideNavRail() {
    return Container(
      width: 68,
      margin: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Center(
              child: Icon(Icons.analytics_rounded, size: 20, color: Colors.white),
            ),
          ),
          const Spacer(),
          _buildRailItem(index: 0, icon: Icons.grid_view_rounded, tooltip: 'Tablolar'),
          const SizedBox(height: 14),
          _buildRailItem(index: 1, icon: Icons.terminal_rounded, tooltip: 'SQL'),
          const SizedBox(height: 14),
          _buildRailItem(index: 2, icon: Icons.dns_rounded, tooltip: 'Bağlantılar'),
          const SizedBox(height: 14),
          _buildRailItem(index: 3, icon: Icons.tune_rounded, tooltip: 'Ayarlar'),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildRailItem({
    required int index,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _currentIndex == index;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (index == 1 && _currentIndex != 1) {
            setState(() {
              _selectedTableForQuery = null;
              _currentIndex = 1;
            });
          } else {
            setState(() => _currentIndex = index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.white.withAlpha(150),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomNav(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      child: Container(
        margin: EdgeInsets.fromLTRB(
          isLandscape ? 160 : 54,
          0,
          isLandscape ? 160 : 54,
          isLandscape ? 8 : 20,
        ),
        height: isLandscape ? 48 : 64,
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 8 : 10,
          vertical: isLandscape ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(isLandscape ? 24 : 32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(45),
              blurRadius: isLandscape ? 16 : 24,
              offset: Offset(0, isLandscape ? 4 : 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(index: 0, icon: Icons.grid_view_rounded, isLandscape: isLandscape),
            _buildNavItem(index: 1, icon: Icons.terminal_rounded, isLandscape: isLandscape),
            _buildNavItem(index: 2, icon: Icons.dns_rounded, isLandscape: isLandscape),
            _buildNavItem(index: 3, icon: Icons.tune_rounded, isLandscape: isLandscape),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required bool isLandscape,
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
        width: isSelected ? (isLandscape ? 56 : 68) : (isLandscape ? 42 : 50),
        height: isLandscape ? 38 : 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(isLandscape ? 19 : 24),
        ),
        child: Center(
          child: Icon(
            icon,
            size: isLandscape ? 20 : 24,
            color: isSelected ? Colors.white : Colors.white.withAlpha(130),
          ),
        ),
      ),
    );
  }
}
