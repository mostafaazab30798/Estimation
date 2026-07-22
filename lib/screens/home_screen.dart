// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  String? _pendingMode;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('player_name');
    if (savedName != null && savedName.isNotEmpty) {
      if (mounted) {
        setState(() {
          _nameController.text = savedName;
        });
      }
    }

    // Attempt session recovery
    if (mounted) {
      final provider = context.read<GameProvider>();
      final recovered = await provider.recoverSession();
      if (recovered && mounted) {
        Navigator.pushReplacementNamed(context, '/lobby');
      }
    }
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String? _validateName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'أدخل اسمك أولاً';
    return null;
  }

  Future<void> _host(BuildContext context, int expectedPlayers) async {
    final err = _validateName();
    if (err != null) { _snack(context, err); return; }
    final name = _nameController.text.trim();
    await _saveName(name);
    
    final provider = context.read<GameProvider>();
    await provider.hostGame(name, expectedPlayers: expectedPlayers);
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _joinWithCode(BuildContext context) async {
    final err = _validateName();
    if (err != null) { _snack(context, err); return; }
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _snack(context, 'أدخل كود مكوّن من 6 أحرف');
      return;
    }
    final name = _nameController.text.trim();
    await _saveName(name);
    
    final provider = context.read<GameProvider>();
    await provider.joinGameWithCode(name, code);
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  Future<void> _testMode(BuildContext context) async {
    final err = _validateName();
    if (err != null) { _snack(context, err); return; }
    final name = _nameController.text.trim();
    await _saveName(name);
    
    final provider = context.read<GameProvider>();
    await provider.startTestGame(name);
    if (context.mounted && provider.status == ConnectionStatus.connected) {
      Navigator.pushReplacementNamed(context, '/lobby');
    } else if (context.mounted && provider.status == ConnectionStatus.error) {
      _snack(context, provider.errorMessage);
    }
  }

  void _snack(BuildContext context, String msg) {
    SnackbarHelper.showError(context, msg, title: 'عذراً ⚠️');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final isLoading = provider.status == ConnectionStatus.connecting ||
        provider.isSearching;
    final isPortrait = MediaQuery.of(context).size.width < 800;

    final contentWidget = isPortrait
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                _buildBrand(),
                const SizedBox(height: 16),
                _buildSuitRow(),
                const SizedBox(height: 24),
                _buildCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        hint: 'اسمك في اللعبة',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 20),
                      if (isLoading)
                        _buildLoading(context, provider)
                      else
                        _buildButtons(context, isPortrait: isPortrait),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              child: Row(
                children: [
                  // ── Left Side: Brand ───────────────────────────
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildBrand(),
                          const SizedBox(height: 32),
                          _buildSuitRow(),
                        ],
                      ),
                    ),
                  ),
                  
                  // Divider
                  Container(
                    width: 1,
                    height: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                    color: Colors.white12,
                  ),
                  
                  // ── Right Side: Interactive Card ────────────────
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: _buildCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              hint: 'اسمك في اللعبة',
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 20),
                            if (isLoading)
                              _buildLoading(context, provider)
                            else
                              _buildButtons(context, isPortrait: isPortrait),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideIn,
              child: contentWidget,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        // Glowing icon
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: AppTheme.glowShadow,
          ),
          child: Image.asset(
            'assets/poker.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.mintSoft, AppTheme.accentLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'إستميشن',
            style: GoogleFonts.alexandria(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF253070), AppTheme.navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.accentBlue.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildButtons(BuildContext context, {required bool isPortrait}) {
    final hostBtn = _primaryBtn(
      label: _pendingMode == 'host' ? 'إلغاء' : 'استضافة',
      icon: _pendingMode == 'host' ? Icons.close_rounded : Icons.wifi_tethering_rounded,
      onTap: () {
        setState(() => _pendingMode = _pendingMode == 'host' ? null : 'host');
      },
    );

    final joinBtn = _secondaryBtn(
      label: _pendingMode == 'join' ? 'إلغاء' : 'انضمام',
      icon: _pendingMode == 'join' ? Icons.close_rounded : Icons.vpn_key_rounded,
      onTap: () => setState(
          () => _pendingMode = _pendingMode == 'join' ? null : 'join'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPortrait) ...[
          hostBtn,
          const SizedBox(height: 12),
          joinBtn,
        ] else ...[
          Row(
            children: [
              Expanded(child: hostBtn),
              const SizedBox(width: 12),
              Expanded(child: joinBtn),
            ],
          ),
        ],
        
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _pendingMode == 'host'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      'كم لاعب حقيقي سيلعب؟ (الباقي بوتات)',
                      style: GoogleFonts.cairo(color: AppTheme.accentLight, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _secondaryBtn(label: '2', icon: Icons.person, onTap: () => _host(context, 2))),
                        const SizedBox(width: 8),
                        Expanded(child: _secondaryBtn(label: '3', icon: Icons.people, onTap: () => _host(context, 3))),
                        const SizedBox(width: 8),
                        Expanded(child: _secondaryBtn(label: '4', icon: Icons.groups, onTap: () => _host(context, 4))),
                      ],
                    ),
                  ],
                )
              : _pendingMode == 'join'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _codeController,
                          hint: 'أدخل الكود (٦ أحرف)',
                          icon: Icons.tag_rounded,
                          keyboardType: TextInputType.visiblePassword,
                          maxLength: 6,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _primaryBtn(
                          label: 'ابحث وانضم',
                          icon: Icons.search_rounded,
                          onTap: () => _joinWithCode(context),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
        ),

        const SizedBox(height: 16),

        // ── Divider ─────────────────────────────────
        Row(children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('أو',
                style: GoogleFonts.cairo(
                    color: AppTheme.accentLight.withValues(alpha: 0.6),
                    fontSize: 12)),
          ),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
        ]),

        const SizedBox(height: 16),

        // ── Bottom Row ──────────────────────────────
        if (isPortrait) ...[
          _secondaryBtn(
            label: 'تجربة ضد البوتات',
            icon: Icons.smart_toy_rounded,
            onTap: () {
              setState(() => _pendingMode = null);
              _testMode(context);
            },
            dimmed: true,
          ),
          const SizedBox(height: 12),
          _secondaryBtn(
            label: 'سجل المباريات',
            icon: Icons.history_rounded,
            onTap: () => Navigator.pushNamed(context, '/history'),
            dimmed: true,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _secondaryBtn(
                  label: 'تجربة ضد البوتات',
                  icon: Icons.smart_toy_rounded,
                  onTap: () {
                    setState(() => _pendingMode = null);
                    _testMode(context);
                  },
                  dimmed: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _secondaryBtn(
                  label: 'سجل المباريات',
                  icon: Icons.history_rounded,
                  onTap: () => Navigator.pushNamed(context, '/history'),
                  dimmed: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Reusable button primitives ───────────────────────────────

  Widget _primaryBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: AppTheme.white),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: AppTheme.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool dimmed = false,
  }) {
    final color = dimmed
        ? AppTheme.accentLight.withValues(alpha: 0.55)
        : AppTheme.accentLight;
    final borderColor = dimmed
        ? AppTheme.accentLight.withValues(alpha: 0.25)
        : AppTheme.accentLight.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppTheme.accentLight),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: AppTheme.accentLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context, GameProvider provider) {
    final msg = provider.isSearching ? 'نبحث عن غرفتك...' : 'جاري الاتصال...';
    return Column(
      children: [
        const SizedBox(height: 8),
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
              color: AppTheme.accentBlue, strokeWidth: 3),
        ),
        const SizedBox(height: 14),
        Text(msg, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        _textBtn(
          label: 'إلغاء',
          icon: Icons.close_rounded,
          onTap: () => context.read<GameProvider>().reset(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSuitRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final e in [
          ('♠', AppTheme.accentLight),
          ('♥', AppTheme.suitRed),
          ('♦', AppTheme.suitRed),
          ('♣', AppTheme.accentLight),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(e.$1,
                style: TextStyle(
                    fontSize: 20,
                    color: e.$2.withValues(alpha: 0.45))),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    TextAlign textAlign = TextAlign.right,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    return TextField(
      controller: controller,
      textAlign: textAlign,
      textDirection: textDirection,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: GoogleFonts.cairo(
        color: AppTheme.mintSoft,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: textAlign == TextAlign.center ? 3 : 0,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(
          color: AppTheme.accentLight.withValues(alpha: 0.5),
          fontSize: 15,
        ),
        prefixIcon:
            Icon(icon, color: AppTheme.accentLight.withValues(alpha: 0.7), size: 20),
        counterText: '',
        filled: true,
        fillColor: AppTheme.navyDark.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accentBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
