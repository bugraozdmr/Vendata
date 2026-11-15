import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/db_connection.dart';
import '../providers/connection_provider.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onConnected;

  const ConnectionsScreen({super.key, this.onConnected});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  Future<void> _openForm({DbConnection? existing}) async {
    final result = await showModalBottomSheet<_FormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConnectionFormSheet(existing: existing),
    );

    if (result == null) return;

    ref.read(connectionsProvider.notifier).save(result.connection);
    if (!result.connect) {
      _showSnack('Bağlantı kaydedildi.');
      return;
    }
    await _connect(result.connection);
  }

  Future<void> _connect(DbConnection connection) async {
    final ok = await ref.read(connectionsProvider.notifier).connect(connection);
    if (!mounted) return;
    if (ok) {
      _showSnack('${connection.name} bağlantısı kuruldu.');
      widget.onConnected?.call();
    } else {
      final error = ref.read(connectionsProvider).errorMessage ?? 'Bağlantı kurulamadı.';
      _showError(error);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bağlantılar',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -1.0,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: state.isConnecting ? null : () => _openForm(),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: state.isConnecting ? AppColors.textMuted : AppColors.accent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: state.isConnecting
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.accent.withAlpha(45),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.isConnecting)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        else
                          const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Yeni Bağlantı',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (state.isConnecting) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.accent.withAlpha(60), width: 1.5),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Sunucuya bağlanılıyor...',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _buildRemoteInfoCard(),
            const SizedBox(height: 18),
            if (state.activeConnection != null) ...[
              _buildActiveCard(state.activeConnection!),
              const SizedBox(height: 18),
            ],
            Row(
              children: [
                Text(
                  'Kayıtlı Bağlantılar',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.connections.length}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.connections.isEmpty)
              _buildEmptyState()
            else
              ...state.connections.map(
                (c) => _buildConnectionCard(c, isActive: state.activeConnection?.id == c.id),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentBlueWash,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.dns_rounded, size: 22, color: AppColors.accentBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uzak Veritabanları',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PostgreSQL ve MySQL/MariaDB sunucularına bağlanıp tablolarınızı sorgulayın. '
                  'Bağlantı bilgileri bu cihazda saklanır.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(DbConnection connection) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.successWash,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.success.withAlpha(70), width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconFor(connection.type), size: 20, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Aktif Bağlantı',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  connection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${connection.type.label} · ${connection.endpoint}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(connectionsProvider.notifier).disconnect();
              _showSnack('Bağlantı kesildi. Yerel veriler gösteriliyor.');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off_rounded, size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    'Kes',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textMuted.withAlpha(100)),
          const SizedBox(height: 12),
          Text(
            'Henüz Bağlantı Yok',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bir PostgreSQL veya MySQL sunucusu ekleyerek başlayın.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(DbConnection connection, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? Border.all(color: AppColors.success.withAlpha(70), width: 1.4) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconFor(connection.type), size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  connection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${connection.type.label} · ${connection.endpoint}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Seçenekler',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Colors.white,
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openForm(existing: connection);
                  break;
                case 'delete':
                  _confirmDelete(connection);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'edit',
                child: Text('Düzenle', style: GoogleFonts.dmSans(fontSize: 13)),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Sil',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error),
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.cardMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _connect(connection),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.success : AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Aktif' : 'Bağlan',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DbConnection connection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Bağlantıyı Sil',
          style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${connection.name} bağlantısı silinecek. Sunucudaki verilere dokunulmaz.',
          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(connectionsProvider.notifier).delete(connection.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Sil',
              style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(DbType type) {
    switch (type) {
      case DbType.postgresql:
        return Icons.storage_rounded;
      case DbType.mysql:
        return Icons.dns_rounded;
    }
  }
}

class _FormResult {
  final DbConnection connection;
  final bool connect;

  const _FormResult(this.connection, {required this.connect});
}

class _ConnectionFormSheet extends ConsumerStatefulWidget {
  final DbConnection? existing;

  const _ConnectionFormSheet({this.existing});

  @override
  ConsumerState<_ConnectionFormSheet> createState() => _ConnectionFormSheetState();
}

class _ConnectionFormSheetState extends ConsumerState<_ConnectionFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _uri;
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _database;
  late final TextEditingController _username;
  late final TextEditingController _password;

  late DbType _type;
  late bool _useSsl;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? DbType.postgresql;
    _uri = TextEditingController();
    _name = TextEditingController(text: existing?.name ?? '');
    _host = TextEditingController(text: existing?.host ?? 'localhost');
    _port = TextEditingController(text: (existing?.port ?? _type.defaultPort).toString());
    _database = TextEditingController(text: existing?.database ?? '');
    _username = TextEditingController(text: existing?.username ?? '');
    _password = TextEditingController(text: existing?.password ?? '');
    _useSsl = existing?.useSsl ?? false;
  }

  @override
  void dispose() {
    _uri.dispose();
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _database.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  DbConnection _buildConnection() {
    final notifier = ref.read(connectionsProvider.notifier);
    return notifier.buildConnection(
      id: widget.existing?.id,
      name: _name.text,
      type: _type,
      host: _host.text,
      port: int.tryParse(_port.text.trim()) ?? _type.defaultPort,
      database: _database.text,
      username: _username.text,
      password: _password.text,
      useSsl: _useSsl,
    );
  }

  void _applyUri() {
    final parsed = DbConnection.tryParseUri(_uri.text);
    if (parsed == null) {
      setState(() {
        _testOk = false;
        _testMessage =
            'Bağlantı dizesi anlaşılamadı. postgresql:// veya mysql:// ile başlamalı.';
      });
      return;
    }

    setState(() {
      _type = parsed.type;
      _name.text = parsed.name;
      _host.text = parsed.host;
      _port.text = parsed.port.toString();
      _database.text = parsed.database;
      _username.text = parsed.username;
      _password.text = parsed.password;
      _useSsl = parsed.useSsl;
      _testMessage = null;
    });
  }

  Future<void> _test() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    final error = await ref.read(connectionsProvider.notifier).test(_buildConnection());
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = error == null;
      _testMessage = error ?? 'Bağlantı başarılı.';
    });
  }

  void _submit({required bool connect}) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _FormResult(_buildConnection(), connect: connect));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.existing == null ? 'Yeni Bağlantı' : 'Bağlantıyı Düzenle',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 16),
              _buildUriField(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Neon, PlanetScale vb. bağlantı dizesini yapıştırıp "Doldur"a basın.',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildTypeSelector(),
              const SizedBox(height: 14),
              _field(label: 'Bağlantı Adı', controller: _name, hint: 'Üretim DB'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(
                      label: 'Sunucu (Host)',
                      controller: _host,
                      hint: 'db.example.com',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Host gerekli' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _field(
                      label: 'Port',
                      controller: _port,
                      hint: '${_type.defaultPort}',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final p = int.tryParse(v?.trim() ?? '');
                        if (p == null || p < 1 || p > 65535) return 'Geçersiz port';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Veritabanı',
                controller: _database,
                hint: 'veritabani_adi',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Veritabanı gerekli' : null,
              ),
              const SizedBox(height: 12),
              _field(label: 'Kullanıcı Adı', controller: _username, hint: 'kullanici'),
              const SizedBox(height: 12),
              _field(
                label: 'Şifre',
                controller: _password,
                hint: '••••••••',
                obscureText: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SSL / TLS kullan',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _useSsl,
                    activeThumbColor: AppColors.accent,
                    onChanged: (v) => setState(() => _useSsl = v),
                  ),
                ],
              ),
              if (_testMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testOk ? AppColors.successWash : AppColors.errorWash,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _testMessage!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: _testOk ? AppColors.success : AppColors.error,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _testing ? null : _test,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              )
                            : Text(
                                'Test Et',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _submit(connect: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Kaydet ve Bağlan',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => _submit(connect: false),
                  child: Text(
                    'Sadece Kaydet',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUriField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bağlantı Dizesi (URL)',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _uri,
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'postgresql://kullanici:sifre@host:5432/db?sslmode=require',
                    hintStyle: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _applyUri(),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _applyUri,
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    'Doldur',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: DbType.values.map((type) {
        final selected = _type == type;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                final previousDefault = _type.defaultPort.toString();
                _type = type;
                if (_port.text.trim().isEmpty || _port.text.trim() == previousDefault) {
                  _port.text = type.defaultPort.toString();
                }
                _testMessage = null;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: type == DbType.values.last ? 0 : 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? AppColors.primary : AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    type == DbType.postgresql ? Icons.storage_rounded : Icons.dns_rounded,
                    size: 18,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
