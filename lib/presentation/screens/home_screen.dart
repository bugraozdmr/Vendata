import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';
import '../../core/theme/app_colors.dart';
import '../providers/database_provider.dart';
import '../providers/theme_provider.dart';
import 'connections_screen.dart';
import 'ai_chat_screen.dart';
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
  final QuickActions _quickActions = const QuickActions();

  @override
  void initState() {
    super.initState();
    _initQuickActions();
  }

  Future<void> _initQuickActions() async {
    try {
      await _quickActions.initialize(_handleQuickAction);
      await _quickActions.setShortcutItems(<ShortcutItem>[
        const ShortcutItem(
          type: 'action_new_query',
          localizedTitle: 'Yeni Sorgu',
          icon: 'ic_shortcut_query',
        ),
        const ShortcutItem(
          type: 'action_upload_file',
          localizedTitle: 'Dosya Yükle',
          icon: 'ic_shortcut_file',
        ),
        const ShortcutItem(
          type: 'action_connections',
          localizedTitle: 'Bağlantılar',
          localizedSubtitle: 'Sunucu bağlantıları',
          icon: 'ic_shortcut_server',
        ),
      ]);
    } catch (_) {}
  }

  void _handleQuickAction(String shortcutType) {
    if (!mounted) return;

    switch (shortcutType) {
      case 'action_new_query':
        setState(() {
          _selectedTableForQuery = null;
          _currentIndex = 1;
        });
        break;
      case 'action_upload_file':
        setState(() => _currentIndex = 0);
        WidgetsBinding.instance.addPostFrameCallback((_) => _pickFile());
        break;
      case 'action_connections':
        setState(() => _currentIndex = 3);
        break;
    }
  }

  Future<void> _pickFile() async {
    if (!mounted) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'tsv', 'sql', 'db', 'sqlite'],
      );
      if (files.isEmpty || files.first.path == null) return;
      final file = files.first;
      await ref.read(tablesProvider.notifier).importFromFile(
            filePath: file.path!,
            fileName: file.name,
          );
    } catch (_) {}
  }

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
    ref.watch(themeModeProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final pages = [
      TablesScreen(onNavigateToSql: _navigateToQuery),
      SqlScreen(targetTable: _selectedTableForQuery),
      AiChatScreen(
        onBackToHome: () => setState(() => _currentIndex = 0),
        onNavigateToSql: (sql, tableName) {
          if (tableName != null) {
            _selectedTableForQuery = tableName;
          }
          ref.read(queryProvider.notifier).setSql(sql);
          setState(() => _currentIndex = 1);
        },
      ),
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

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final isChatTab = _currentIndex == 2;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: (isLandscape || keyboardVisible || isChatTab)
            ? null
            : _buildFloatingBottomNav(context),
      ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF15161A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(30), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
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
                    const Spacer(),
                    _buildRailItem(index: 0, icon: Icons.grid_view_rounded, tooltip: 'Tablolar'),
                    const SizedBox(height: 12),
                    _buildRailItem(index: 1, icon: Icons.terminal_rounded, tooltip: 'SQL'),
                    const SizedBox(height: 12),
                    _buildRailItem(index: 2, icon: Icons.auto_awesome_rounded, tooltip: 'AI Sohbet'),
                    const SizedBox(height: 12),
                    _buildRailItem(index: 3, icon: Icons.dns_rounded, tooltip: 'Bağlantılar'),
                    const SizedBox(height: 12),
                    _buildRailItem(index: 4, icon: Icons.tune_rounded, tooltip: 'Ayarlar'),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        },
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
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 4, 24, 6),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(index: 0, icon: Icons.grid_view_rounded),
            _buildNavItem(index: 1, icon: Icons.terminal_rounded),
            _buildNavItem(index: 2, icon: Icons.auto_awesome_rounded),
            _buildNavItem(index: 3, icon: Icons.dns_rounded),
            _buildNavItem(index: 4, icon: Icons.tune_rounded),
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
        width: isSelected ? 56 : 42,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 21,
            color: isSelected ? Colors.white : Colors.white.withAlpha(140),
          ),
        ),
      ),
    );
  }
}
