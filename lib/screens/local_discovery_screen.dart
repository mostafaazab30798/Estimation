// lib/screens/local_discovery_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../networking/local/local_discovery_service.dart';
import '../providers/game_provider.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';
import '../widgets/performance_blur.dart';

class LocalDiscoveryScreen extends StatefulWidget {
  const LocalDiscoveryScreen({super.key});

  @override
  State<LocalDiscoveryScreen> createState() => _LocalDiscoveryScreenState();
}

class _LocalDiscoveryScreenState extends State<LocalDiscoveryScreen>
    with TickerProviderStateMixin {
  final LocalDiscoveryService _discoveryService = LocalDiscoveryService();
  StreamSubscription<List<DiscoveredRoom>>? _sub;
  List<DiscoveredRoom> _discoveredRooms = [];
  bool _isSearching = true;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '7890');
  String _playerName = '';
  String? _myLocalIp;
  String? _connectingRoomIp;
  int _selectedFilter = 0; // 0: All, 1: Estimation, 2: 99 Mode

  // Animations
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  late final AnimationController _radarCtrl;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPlayerNameAndIp();
    _startScanning();
  }

  void _initAnimations() {
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _entryCtrl.forward();
  }

  Future<void> _loadPlayerNameAndIp() async {
    final name = await ProfileService.getProfileName();
    final ip = await LocalDiscoveryService.getLocalIpAddress();
    if (mounted) {
      setState(() {
        _playerName = name;
        _myLocalIp = ip;
      });
    }
  }

  void _startScanning() {
    _sub?.cancel();
    setState(() => _isSearching = true);
    if (!_radarCtrl.isAnimating) _radarCtrl.repeat();

    _sub = _discoveryService.startScan().listen(
      (rooms) {
        if (mounted) {
          setState(() {
            _discoveredRooms = rooms;
            _isSearching = false;
          });
          _radarCtrl.stop();
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _isSearching = false);
          _radarCtrl.stop();
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ipController.dispose();
    _portController.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _radarCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectToRoom(DiscoveredRoom room) async {
    if (_playerName.trim().isEmpty) {
      SnackbarHelper.showError(context, 'يرجى تعيين اسمك في الملف الشخصي أولاً');
      return;
    }
    setState(() => _connectingRoomIp = room.ip);

    try {
      final provider = context.read<GameProvider>();
      await provider.joinLocalGame(_playerName, room.ip, room.port, expectedGameType: room.gameType);
      if (mounted) {
        if (provider.status == ConnectionStatus.connected) {
          Navigator.pushReplacementNamed(context, '/lobby');
        } else if (provider.status == ConnectionStatus.error) {
          SnackbarHelper.showError(context, provider.errorMessage);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _connectingRoomIp = null);
      }
    }
  }

  Future<void> _connectManual() async {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();
    if (ip.isEmpty) {
      SnackbarHelper.showWarning(context, 'أدخل عنوان IP الخادم');
      return;
    }
    final port = int.tryParse(portStr) ?? 7890;
    
    final room = DiscoveredRoom(
      hostName: 'المضيف',
      ip: ip,
      port: port,
      gameType: 'kotchina',
      currentPlayers: 1,
      maxPlayers: 4,
      roomCode: '',
    );
    await _connectToRoom(room);
  }

  List<DiscoveredRoom> get _filteredRooms {
    if (_selectedFilter == 1) {
      return _discoveredRooms.where((r) => r.gameType != 'ninety_nine').toList();
    } else if (_selectedFilter == 2) {
      return _discoveredRooms.where((r) => r.gameType == 'ninety_nine').toList();
    }
    return _discoveredRooms;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Wallpaper Background ──────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/wallpapers/w1.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
              ),
            ),
          ),

          // ── 2. Dark Overlay Gradient ────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    AppTheme.deepNavy.withValues(alpha: 0.88),
                    AppTheme.deepNavy,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── 3. Ambient Pulsing Orbs ──────────────────────────────
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) {
              final t = _pulseAnim.value;
              return Stack(
                children: [
                  Positioned(
                    top: -60 + t * 15,
                    right: -60 + t * 10,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.gold.withValues(alpha: 0.10 + t * 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -60 + (1 - t) * 15,
                    left: -60 + (1 - t) * 10,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.midBlue.withValues(alpha: 0.12 + (1 - t) * 0.06),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── 4. Main Screen Content ──────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: Column(
                  children: [
                    // Top Bar Header
                    _buildHeader(context),

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // My Local IP Pill & Info
                            _buildMyIpCard(),

                            const SizedBox(height: 16),

                            // Filter Chips (All, Estimation, 99 Mode)
                            _buildFilterChips(),

                            const SizedBox(height: 18),

                            // Discovered Rooms List / Radar / Empty State
                            _buildDiscoveredSection(),

                            const SizedBox(height: 24),

                            // Manual Connection Form Card
                            _buildManualConnectCard(),
                            
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Widget ──────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.glassDecoration(
        borderRadius: 20,
        fillColor: AppTheme.navyDark.withValues(alpha: 0.65),
        borderColor: AppTheme.steelBlue.withValues(alpha: 0.2),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surface2.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.cream,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'البحث عن مباراة',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cream,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_isSearching ? AppTheme.gold : Colors.greenAccent)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_isSearching ? AppTheme.gold : Colors.greenAccent)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isSearching ? AppTheme.gold : Colors.greenAccent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isSearching ? 'جاري المسح...' : 'مستعد',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isSearching ? AppTheme.gold : Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'الألعاب القريبة على شبكة الـ Wi-Fi / LAN',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppTheme.steelBlue,
                  ),
                ),
              ],
            ),
          ),

          // Refresh Action Button
          // RotationTransition(
          //   turns: _isSearching ? _radarCtrl : const AlwaysStoppedAnimation(0),
          //   child: IconButton(
          //     onPressed: _startScanning,
          //     icon: const Icon(Icons.refresh_rounded, color: AppTheme.gold),
          //     tooltip: 'إعادة البحث',
          //   ),
          // ),
        ],
      ),
    );
  }

  // ── My IP Address Banner Card ─────────────────────────────────────────────

  Widget _buildMyIpCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.glassDecoration(
        borderRadius: 16,
        fillColor: AppTheme.surface2.withValues(alpha: 0.4),
        borderColor: AppTheme.accentBlue.withValues(alpha: 0.25),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.midBlue.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wifi_rounded, color: AppTheme.steelBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عنوان IP الخاص بك (للشبكة المحلية):',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppTheme.steelBlue,
                  ),
                ),
                Text(
                  _myLocalIp ?? 'جاري التحديد...',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cream,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (_myLocalIp != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: AppTheme.gold, size: 18),
              tooltip: 'نسخ عنوان IP',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _myLocalIp!));
                SnackbarHelper.showSuccess(context, 'تم نسخ عنوان IP الحافظة 📋');
              },
            ),
        ],
      ),
    );
  }

  // ── Mode Filter Chips ──────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'الكل', 'icon': Icons.grid_view_rounded, 'color': AppTheme.gold},
      {'label': 'إستميشن ♠', 'icon': Icons.style_rounded, 'color': AppTheme.goldLight},
      {'label': 'مود الـ 99 🔥', 'icon': Icons.local_fire_department_rounded, 'color': const Color(0xFFEF4444)},
    ];

    return Row(
      children: List.generate(filters.length, (index) {
        final isSelected = _selectedFilter == index;
        final color = filters[index]['color'] as Color;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == filters.length - 1 ? 0 : 4,
              right: index == 0 ? 0 : 4,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedFilter = index),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.25)
                          : AppTheme.navyDark.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : AppTheme.steelBlue.withValues(alpha: 0.2),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        filters[index]['label'] as String,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.cream : AppTheme.steelBlue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Discovered Rooms List / Radar / Empty State ───────────────────────────

  Widget _buildDiscoveredSection() {
    final rooms = _filteredRooms;

    if (_isSearching && rooms.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: AppTheme.glassDecoration(
          borderRadius: 24,
          fillColor: AppTheme.navyDark.withValues(alpha: 0.6),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              width: 120,
              child: AnimatedBuilder(
                animation: _radarCtrl,
                builder: (_, __) {
                  return CustomPaint(
                    painter: _RadarPainter(
                      progress: _radarCtrl.value,
                      color: AppTheme.gold,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.wifi_find_rounded,
                        color: AppTheme.gold,
                        size: 38,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'جاري البحث عن ألعاب قريبة...',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.cream,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'يرجى التأكد من تشغيل الواي فاي أو الهوتسبوت وأن المضيف أنشأ غرفة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppTheme.steelBlue,
              ),
            ),
          ],
        ),
      );
    }

    if (rooms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: AppTheme.glassDecoration(
          borderRadius: 24,
          fillColor: AppTheme.navyDark.withValues(alpha: 0.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.steelBlue.withValues(alpha: 0.12),
                border: Border.all(color: AppTheme.steelBlue.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppTheme.steelBlue,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لم يتم العثور على ألعاب متاحة',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.cream,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'تأكد أن المضيف قد أنشأ غرفة أوفلاين وهو متصل بـ Wi-Fi أو Hotspot معك',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppTheme.steelBlue,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _startScanning,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'إعادة البحث الآن',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.gold,
                side: const BorderSide(color: AppTheme.gold, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.videogame_asset_rounded, color: AppTheme.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'الغرف المكتشفة (${rooms.length})',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cream,
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final room = rooms[index];
            return _buildRoomCard(room);
          },
        ),
      ],
    );
  }

  // ── Single Discovered Room Card ───────────────────────────────────────────

  Widget _buildRoomCard(DiscoveredRoom room) {
    final is99 = room.gameType == 'ninety_nine';
    final accentColor = is99 ? const Color(0xFFEF4444) : AppTheme.gold;
    final isConnectingThis = _connectingRoomIp == room.ip;

    return PerformanceBlur(
      child: Container(
        decoration: AppTheme.glassDecoration(
          borderRadius: 20,
          borderColor: accentColor.withValues(alpha: 0.45),
          fillColor: AppTheme.navyDark.withValues(alpha: 0.7),
          shadows: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isConnectingThis ? null : () => _connectToRoom(room),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Game Mode Badge Circle
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: is99
                            ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
                            : [AppTheme.gold, AppTheme.goldDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      is99 ? '99' : '♠',
                      style: TextStyle(
                        fontSize: is99 ? 20 : 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Room Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                room.hostName,
                                style: GoogleFonts.cairo(
                                  color: AppTheme.cream,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                is99 ? 'مود الـ 99' : 'إستميشن',
                                style: GoogleFonts.cairo(
                                  color: accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.lan_rounded, size: 13, color: AppTheme.steelBlue),
                            const SizedBox(width: 4),
                            Text(
                              'IP: ${room.ip}:${room.port}',
                              style: GoogleFonts.cairo(
                                color: AppTheme.steelBlue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Player Count Chip & Join Button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_rounded, size: 14, color: AppTheme.gold),
                            const SizedBox(width: 4),
                            Text(
                              '${room.currentPlayers}/${room.maxPlayers}',
                              style: GoogleFonts.cairo(
                                color: AppTheme.cream,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: isConnectingThis ? null : () => _connectToRoom(room),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                          ),
                          child: isConnectingThis
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'انضمام',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Manual Connection Card ────────────────────────────────────────────────

  Widget _buildManualConnectCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
        borderRadius: 22,
        fillColor: AppTheme.navyDark.withValues(alpha: 0.65),
        borderColor: AppTheme.accentBlue.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.steelBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الاتصال المباشر عبر IP',
                      style: GoogleFonts.cairo(
                        color: AppTheme.cream,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'استخدم هذا النموذج إذا لم تظهر الغرفة تلقائياً',
                      style: GoogleFonts.cairo(
                        color: AppTheme.steelBlue,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 7,
                child: TextField(
                  controller: _ipController,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lan_rounded, color: AppTheme.steelBlue, size: 18),
                    labelText: 'عنوان IP',
                    hintText: '192.168.1.10',
                    labelStyle: GoogleFonts.cairo(color: AppTheme.steelBlue, fontSize: 12),
                    hintStyle: GoogleFonts.cairo(color: AppTheme.steelBlue.withValues(alpha: 0.4), fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.surface2.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.steelBlue.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'المنفذ',
                    hintText: '7890',
                    labelStyle: GoogleFonts.cairo(color: AppTheme.steelBlue, fontSize: 12),
                    hintStyle: GoogleFonts.cairo(color: AppTheme.steelBlue.withValues(alpha: 0.4), fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.surface2.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.steelBlue.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _connectManual,
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  'اتصال مباشر بالغرفة',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.1,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: AppTheme.accentBlue.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Radar Sweeper Painter ─────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    // Outer concentric rings
    for (int i = 1; i <= 3; i++) {
      final r = (maxRadius / 3) * i;
      final ringPaint = Paint()
        ..color = color.withValues(alpha: 0.12 * i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, r, ringPaint);
    }

    // Pulsing expanding wave
    final pulseRadius = maxRadius * progress;
    final pulsePaint = Paint()
      ..color = color.withValues(alpha: (1 - progress) * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Rotating Radar Sweep Line
    final angle = progress * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.35),
        ],
        stops: const [0.75, 1.0],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
