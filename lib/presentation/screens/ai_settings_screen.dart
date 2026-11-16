import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/ai_providers_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/ai_provider.dart';
import '../providers/ai_provider.dart';

class AISettingsScreen extends ConsumerStatefulWidget {
  const AISettingsScreen({super.key});

  @override
  ConsumerState<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends ConsumerState<AISettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(aiSettingsProvider);
    final active = ref.watch(activeAiProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Yapay Zeka (AI) Ayarları',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yeni Sağlayıcı Ekle',
            icon: Icon(Icons.add_rounded, color: AppColors.accent, size: 24),
            onPressed: () => _showAddCustomProviderDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, isLandscape ? 24 : 90),
          physics: const BouncingScrollPhysics(),
          children: [
            // Active model summary banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withAlpha(50), width: 1.2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktif Yapay Zeka',
                          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active != null ? '${active.name} · ${active.modelName}' : 'Seçili model yok',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          active != null && active.apiKey.isNotEmpty
                              ? 'API anahtarı hazır'
                              : 'API anahtarı girilmedi',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: active != null && active.apiKey.isNotEmpty ? AppColors.success : AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Sağlayıcılar & Modeller',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            ...providers.map((p) => _ProviderCard(provider: p)),
          ],
        ),
      ),
    );
  }

  void _showAddCustomProviderDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'http://localhost:11434/v1/chat/completions');
    final modelCtrl = TextEditingController(text: 'llama3');
    final keyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Özel AI Sağlayıcı Ekle',
                    style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInput('Sağlayıcı Adı (Örn: Ollama, Yerel Sunucu)', nameCtrl),
              const SizedBox(height: 12),
              _buildInput('API Endpoint URL', urlCtrl),
              const SizedBox(height: 12),
              _buildInput('Model Adı (Örn: llama3, mistral)', modelCtrl),
              const SizedBox(height: 12),
              _buildInput('API Anahtarı (Opsiyonel)', keyCtrl),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final url = urlCtrl.text.trim();
                    final model = modelCtrl.text.trim();
                    if (name.isEmpty || url.isEmpty || model.isEmpty) return;

                    final newProvider = AIProviderModel(
                      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
                      name: name,
                      providerType: 'custom',
                      modelName: model,
                      apiKey: keyCtrl.text.trim(),
                      baseUrl: url,
                      isActive: true,
                      isPredefined: false,
                      customModels: [model],
                    );

                    ref.read(aiSettingsProvider.notifier).saveProvider(newProvider);
                    ref.read(aiSettingsProvider.notifier).setActive(newProvider.id);
                    Navigator.pop(ctx);
                  },
                  child: Text('Kaydet ve Etkinleştir', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.cardMuted,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
      ],
    );
  }
}

class _ProviderCard extends ConsumerStatefulWidget {
  final AIProviderModel provider;

  const _ProviderCard({required this.provider});

  @override
  ConsumerState<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends ConsumerState<_ProviderCard> {
  late TextEditingController _keyController;
  late String _selectedModel;
  bool _obscureKey = true;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.provider.apiKey);
    _selectedModel = widget.provider.modelName;
  }

  @override
  void didUpdateWidget(covariant _ProviderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.provider.apiKey != oldWidget.provider.apiKey) {
      _keyController.text = widget.provider.apiKey;
    }
    if (widget.provider.modelName != oldWidget.provider.modelName) {
      _selectedModel = widget.provider.modelName;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final testProvider = widget.provider.copyWith(
      apiKey: _keyController.text.trim(),
      modelName: _selectedModel,
    );

    try {
      final ms = await ref.read(aiSettingsProvider.notifier).testConnection(testProvider);
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = true;
        _testResult = 'Bağlantı başarılı ($ms ms)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testResult = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _saveChanges() {
    final updated = widget.provider.copyWith(
      apiKey: _keyController.text.trim(),
      modelName: _selectedModel,
    );
    ref.read(aiSettingsProvider.notifier).saveProvider(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.provider.name} ayarları kaydedildi.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final isActive = p.isActive;
    final preset = AIProvidersConstants.getPresetByType(p.providerType);
    final availableModels = p.allModels;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive ? AppColors.accent : AppColors.border,
          width: isActive ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Radio / Active toggle & Provider Name
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(aiSettingsProvider.notifier).setActive(p.id);
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? AppColors.accent : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                  child: isActive
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.name,
                          style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Aktif',
                              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (preset != null)
                      Text(
                        preset.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              if (!p.isPredefined)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                  onPressed: () => ref.read(aiSettingsProvider.notifier).deleteProvider(p.id),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Model Selector Dropdown
          Text('Model:', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.cardMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: availableModels.contains(_selectedModel) ? _selectedModel : availableModels.first,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                items: availableModels.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedModel = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // API Key Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('API Anahtarı:', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              if (preset != null)
                Text(
                  preset.apiKeyHelpUrl,
                  style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _keyController,
            obscureText: _obscureKey,
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'API Anahtarınızı yapıştırın...',
              hintStyle: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.cardMuted,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent)),
            ),
          ),
          const SizedBox(height: 12),

          // Test Result Message
          if (_testResult != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _testSuccess ? AppColors.successWash : AppColors.errorWash,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (_testSuccess ? AppColors.success : AppColors.error).withAlpha(50)),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 16,
                    color: _testSuccess ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: _testSuccess ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action Buttons: Test Connection & Save
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isTesting ? null : _testConnection,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.cardMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: _isTesting
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, size: 16, color: AppColors.textPrimary),
                                const SizedBox(width: 4),
                                Text(
                                  'Test Et',
                                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _saveChanges,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Kaydet',
                            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
