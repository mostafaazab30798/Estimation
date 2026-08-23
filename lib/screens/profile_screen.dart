// lib/screens/profile_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/profile_service.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../models/rank_tier.dart';
import '../models/estimation_statistics.dart';
import '../models/playstyle_models.dart';
import '../services/playstyle_service.dart';
import '../widgets/rank_tier_badge.dart';
import '../widgets/player_identity_card.dart';
import '../widgets/playstyle_radar_view.dart';
import 'leaderboard_screen.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/utils/string_utils.dart';
import '../core/widgets/player_avatar.dart';
import '../widgets/update_check_tile.dart';

// ---------------------------------------------------------------------------
// Local ChangeNotifier — owns all profile & hub UI state
// ---------------------------------------------------------------------------
class _ProfileViewModel extends ChangeNotifier {
  String currentPhoto = ProfileService.presetAvatars.first.id;
  PlayerStats stats = PlayerStats.empty();
  List<MatchRecord> allHistory = [];
  PlayerPersonalityProfile personalityProfile = PlayerPersonalityProfile.initial();
  PlayerIdentityCardConfig cardConfig = const PlayerIdentityCardConfig();
  bool isLoading = true;
  bool isSavingName = false;
  bool isEditingName = false;
  int currentPage = 0;
  int currentTab = 0; // 0 = Profile, 1 = Leaderboard, 2 = History, 3 = Settings, 4 = Guides
  int selectedModeFilter = 0; // 0 = Estimation, 1 = 99 Mode
  int selectedGuideSubTab = 0; // 0 = Estimation, 1 = 99 Mode
  int selectedProfileSubTab = 0; // 0 = Identity Card, 1 = Playstyle & Personality, 2 = Match Stats, 3 = Account & Rank

  void setProfileSubTab(int subTab) {
    selectedProfileSubTab = subTab;
    notifyListeners();
  }

  void setLoading(bool v) {
    isLoading = v;
    notifyListeners();
  }

  void updateAfterLoad({
    required String photo,
    required PlayerStats stats,
    required List<MatchRecord> history,
    required PlayerPersonalityProfile profile,
    required PlayerIdentityCardConfig config,
  }) {
    currentPhoto = photo;
    this.stats = stats;
    allHistory = history;
    personalityProfile = profile;
    cardConfig = config;
    isLoading = false;
    currentPage = 0;
    notifyListeners();
  }

  void updateAfterSave(PlayerStats newStats) {
    stats = newStats;
    isSavingName = false;
    isEditingName = false;
    notifyListeners();
  }

  void updateCardConfig(PlayerIdentityCardConfig newConfig) {
    cardConfig = newConfig;
    notifyListeners();
  }

  void updatePlaystyleData({
    required PlayerPersonalityProfile profile,
    required PlayerIdentityCardConfig config,
  }) {
    personalityProfile = profile;
    cardConfig = config;
    notifyListeners();
  }

  void setSavingName(bool v) {
    isSavingName = v;
    notifyListeners();
  }

  void setEditingName(bool v) {
    isEditingName = v;
    notifyListeners();
  }

  void setPhoto(String photo) {
    currentPhoto = photo;
    notifyListeners();
  }

  void setPage(int page) {
    currentPage = page;
    notifyListeners();
  }

  void setTab(int tab) {
    currentTab = tab;
    currentPage = 0;
    notifyListeners();
  }

  void setModeFilter(int filter) {
    selectedModeFilter = filter;
    currentPage = 0;
    notifyListeners();
  }

  void setGuideSubTab(int subTab) {
    selectedGuideSubTab = subTab;
    notifyListeners();
  }

  List<MatchRecord> get filteredHistory {
    if (selectedModeFilter == 1) {
      return allHistory.where((m) => m.gameType == 'ninety_nine').toList();
    }
    return allHistory.where((m) => m.gameType != 'ninety_nine').toList();
  }
}

class ProfileScreen extends StatefulWidget {
  final int initialTab;
  const ProfileScreen({super.key, this.initialTab = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  late final _vm = _ProfileViewModel();
  final SettingsService _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _vm.currentTab = widget.initialTab;
    _settings.addListener(_onSettingsChanged);
    _loadProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int && args >= 0 && args <= 4) {
      _vm.setTab(args);
    }
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _nameController.dispose();
    _nameFocus.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _showRankTiersDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.navyDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: AppTheme.gold, width: 1.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.military_tech_rounded, color: AppTheme.gold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'نظام الرتب والمستويات',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.cream,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ارتقِ بمستواك من خلال الفوز بالمباريات وحصد نقاط الخبرة XP لفتح رتب أعلى',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppTheme.steelBlue,
                ),
              ),
              const SizedBox(height: 16),
              ...RankTier.allTiers.map((tier) {
                final isCurrent = AuthService.instance.currentProfile?.rankTier.type == tier.type;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrent ? tier.primaryColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent ? tier.primaryColor : Colors.white12,
                      width: isCurrent ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(tier.badgeEmoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier.titleAr,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: tier.primaryColor,
                              ),
                            ),
                            Text(
                              tier.maxLevel >= 9999
                                  ? 'المستوى ${tier.minLevel}+'
                                  : 'المستويات ${tier.minLevel} - ${tier.maxLevel}',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tier.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'رتبتك الحالية',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.navyDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadProfileData() async {
    _vm.setLoading(true);

    try {
      final authProfile = AuthService.instance.currentProfile;
      String name = authProfile?.username ?? '';
      if (name.isEmpty) {
        name = await ProfileService.getProfileName().timeout(
          const Duration(seconds: 2),
          onTimeout: () => '',
        );
      }
      name = StringUtils.capitalizeWords(name);

      final photo = await ProfileService.getProfilePhoto().timeout(
        const Duration(seconds: 2),
        onTimeout: () => ProfileService.presetAvatars.first.id,
      );
      final stats = await ProfileService.getProfileStats(name).timeout(
        const Duration(seconds: 3),
        onTimeout: () => PlayerStats.empty(),
      );
      final aHistory = name.isNotEmpty
          ? await ProfileService.getPlayerHistory(name)
          : await HistoryService.getHistory();

      final personalityProfile = await PlaystyleService.instance
          .getPersonalityProfile(name, stats.estimationStats)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => PlayerPersonalityProfile.initial(),
          );
      final cardConfig = await PlaystyleService.instance
          .getIdentityCardConfig(name)
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => const PlayerIdentityCardConfig(),
          );

      if (mounted) {
        _nameController.text = name;
        _vm.updateAfterLoad(
          photo: photo,
          stats: stats,
          history: aHistory,
          profile: personalityProfile,
          config: cardConfig,
        );
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Error loading profile data: $e');
      if (mounted) {
        _vm.setLoading(false);
      }
    }
  }

  Future<void> _handleCardConfigChanged(PlayerIdentityCardConfig newConfig) async {
    _vm.updateCardConfig(newConfig);
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await PlaystyleService.instance.saveIdentityCardConfig(name, newConfig);
    }
  }

  Future<void> _saveName() async {
    final newName = StringUtils.capitalizeWords(_nameController.text.trim());
    if (newName.isEmpty) {
      SnackbarHelper.showError(context, 'يرجى إدخال اسم للاحتفاظ به', title: 'تنبيه');
      return;
    }

    _nameController.text = newName;
    _vm.setSavingName(true);
    await ProfileService.saveProfileName(newName);
    await AuthService.instance.updateProfile(username: newName);
    final stats = await ProfileService.getProfileStats(newName);
    final personalityProfile = await PlaystyleService.instance.getPersonalityProfile(newName, stats.estimationStats);
    final cardConfig = await PlaystyleService.instance.getIdentityCardConfig(newName);

    if (mounted) {
      _vm.updateAfterSave(stats);
      _vm.updatePlaystyleData(profile: personalityProfile, config: cardConfig);
      _nameFocus.unfocus();
      SnackbarHelper.showSuccess(context, 'تم حفظ الاسم بنجاح', title: 'تم الحفظ');
    }
  }

  Future<void> _selectAvatar(String photoData) async {
    await ProfileService.saveProfilePhoto(photoData);
    await AuthService.instance.updateProfile(avatarUrl: photoData);
    if (mounted) {
      _vm.setPhoto(photoData);
      SnackbarHelper.showSuccess(context, 'تم تحديث الصورة الشخصية', title: 'تم الحفظ');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final auth = AuthService.instance;
      final profile = await auth.signInWithGoogle();
      if (profile != null && mounted) {
        final formattedName = StringUtils.capitalizeWords(profile.username);
        _nameController.text = formattedName;
        _vm.setPhoto(profile.avatarUrl);
        await ProfileService.saveProfileName(formattedName);
        await _loadProfileData();
        if (mounted) {
          SnackbarHelper.showSuccess(
            context,
            'أهلاً بك يا $formattedName! تم ربط حساب Google وحفظ التقدم بنجاح',
            title: 'تم تسجيل الدخول',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'تعذر تسجيل الدخول عبر Google: $e',
          title: 'خطأ في المصادقة',
        );
      }
    }
  }

  Future<void> _handleGoogleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(
          'تسجيل الخروج',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppTheme.cream),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من حساب Google؟ سيظل تقدمك محفوظاً في السحابة.',
          style: GoogleFonts.cairo(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('تسجيل الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.instance.signOut();
      if (mounted) {
        await _loadProfileData();
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'تم تسجيل الخروج بنجاح', title: 'تم الخروج');
        }
      }
    }
  }

  void _openAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.navyDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: Colors.white12),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppTheme.gold, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'اختر صورة الملف الشخصي',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mintSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      itemCount: ProfileService.presetAvatars.length,
                      itemBuilder: (context, index) {
                        final avatar = ProfileService.presetAvatars[index];
                        final isSelected = _vm.currentPhoto == avatar.id;

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _selectAvatar(avatar.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: avatar.gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: isSelected ? AppTheme.gold : Colors.white24,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected ? AppTheme.glowShadow : [],
                            ),
                            child: Center(
                              child: Text(
                                avatar.emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 256,
                          maxHeight: 256,
                          imageQuality: 85,
                        );
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          final base64String = base64Encode(bytes);
                          await _selectAvatar(base64String);
                        }
                      },
                      icon: const Icon(Icons.photo_library_rounded, color: AppTheme.accentLight),
                      label: Text(
                        'اختيار صورة من المعرض',
                        style: GoogleFonts.cairo(
                          color: AppTheme.accentLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.accentBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<_ProfileViewModel>.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppTheme.deepNavy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background wallpaper
            Positioned.fill(
              child: Image.asset(
                'assets/wallpapers/w1.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
                ),
              ),
            ),
            // Dark gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.70),
                      AppTheme.deepNavy.withValues(alpha: 0.90),
                      AppTheme.deepNavy,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // App Bar
                  _buildHeaderBar(),

                  // Segmented Tabs Bar (Profile, Leaderboard, History, Settings, Guides)
                  _buildTabBar(),

                  // Tab Content Area
                  Expanded(
                    child: Consumer<_ProfileViewModel>(
                      builder: (context, vm, _) {
                        if (vm.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppTheme.gold),
                          );
                        }

                        switch (vm.currentTab) {
                          case 0:
                            return _buildProfileTab(vm);
                          case 1:
                            return const LeaderboardView();
                          case 2:
                            return _buildHistoryTab(vm);
                          case 3:
                            return _buildSettingsTab();
                          case 4:
                            return _buildGuidesTab(vm);
                          default:
                            return _buildProfileTab(vm);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Header ─────────────────────────────────────────────────────────────

  Widget _buildHeaderBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Back button
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title
                Expanded(
                  child: Text(
                    'مركز اللاعب والتحكم',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.cream,
                    ),
                  ),
                ),

                // Casino Crown Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: AppTheme.gold,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Segmented Navigation Bar ───────────────────────────────────────────────

  Widget _buildTabBar() {
    return Consumer<_ProfileViewModel>(
      builder: (context, vm, _) {
        final tabs = const [
          {'id': 0, 'label': 'الملف الشخصي', 'icon': Icons.person_rounded},
          {'id': 1, 'label': 'المتصدرين', 'icon': Icons.leaderboard_rounded},
          {'id': 2, 'label': 'السجل', 'icon': Icons.history_rounded},
          {'id': 3, 'label': 'الإعدادات', 'icon': Icons.tune_rounded},
          {'id': 4, 'label': 'دليل اللعب', 'icon': Icons.menu_book_rounded},
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isCompact = width < 360;
            final isWide = width >= 640;

            final double marginH = isCompact ? 8.0 : (isWide ? 24.0 : 16.0);
            final double marginV = isCompact ? 6.0 : 10.0;
            final double itemPaddingV = isCompact ? 6.0 : (isWide ? 10.0 : 8.0);
            final double itemPaddingH = isCompact ? 2.0 : (isWide ? 10.0 : 4.0);
            final double iconSize = isCompact ? 16.0 : (isWide ? 20.0 : 18.0);
            final double fontSize = isCompact ? 9.5 : (isWide ? 13.0 : 11.0);

            final tabBarWidget = Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.navyDark.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(isWide ? 20 : 16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: tabs.map((t) {
                  final id = t['id'] as int;
                  final label = t['label'] as String;
                  final icon = t['icon'] as IconData;
                  final isSelected = vm.currentTab == id;

                  return Expanded(
                    child: Tooltip(
                      message: label,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            AudioService.instance.playCard();
                            vm.setTab(id);
                          },
                          borderRadius: BorderRadius.circular(isWide ? 14 : 12),
                          splashColor: AppTheme.gold.withValues(alpha: 0.15),
                          highlightColor: AppTheme.gold.withValues(alpha: 0.08),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: EdgeInsets.symmetric(
                              vertical: itemPaddingV,
                              horizontal: itemPaddingH,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.gold.withValues(alpha: 0.22)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(isWide ? 14 : 12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.gold.withValues(alpha: 0.6)
                                    : Colors.transparent,
                                width: isSelected ? 1.2 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.gold.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        spreadRadius: 0.5,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isWide
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icon,
                                        size: iconSize,
                                        color: isSelected ? AppTheme.gold : Colors.white60,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.cairo(
                                            fontSize: fontSize,
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                            color: isSelected ? AppTheme.goldLight : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        icon,
                                        size: iconSize,
                                        color: isSelected ? AppTheme.gold : Colors.white60,
                                      ),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.cairo(
                                            fontSize: fontSize,
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                            color: isSelected ? AppTheme.goldLight : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: marginH, vertical: marginV),
                  child: tabBarWidget,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Tab 0: Profile & Hub ───────────────────────────────────────────────────

  Widget _buildProfileTab(_ProfileViewModel vm) {
    return Column(
      children: [
        // Sub-segmented navigation pills (Card, Playstyle, Stats, Account)
        _buildProfileSubTabBar(vm),

        // Sub-Tab Content
        Expanded(
          child: _buildProfileSubTabContent(vm),
        ),
      ],
    );
  }

  Widget _buildProfileSubTabBar(_ProfileViewModel vm) {
    final subTabs = const [
      {'id': 0, 'label': 'بطاقة الهوية', 'icon': Icons.badge_rounded},
      {'id': 1, 'label': 'الشخصية والأسلوب', 'icon': Icons.psychology_rounded},
      {'id': 2, 'label': 'الإحصائيات', 'icon': Icons.query_stats_rounded},
      {'id': 3, 'label': 'الحساب والرتبة', 'icon': Icons.shield_rounded},
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: subTabs.map((st) {
                final id = st['id'] as int;
                final label = st['label'] as String;
                final icon = st['icon'] as IconData;
                final isSelected = vm.selectedProfileSubTab == id;

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      AudioService.instance.playCard();
                      vm.setProfileSubTab(id);
                    },
                    borderRadius: BorderRadius.circular(11),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.gold.withValues(alpha: 0.22) : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: isSelected ? AppTheme.gold.withValues(alpha: 0.6) : Colors.transparent,
                          width: 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.gold.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: isSelected ? AppTheme.goldLight : Colors.white60,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                style: GoogleFonts.cairo(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                  color: isSelected ? AppTheme.goldLight : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSubTabContent(_ProfileViewModel vm) {
    switch (vm.selectedProfileSubTab) {
      case 0:
        return _buildIdentityCardSubTab(vm);
      case 1:
        return _buildPlaystylePersonalitySubTab(vm);
      case 2:
        return _buildMatchStatsSubTab(vm);
      case 3:
        return _buildAccountAndTierSubTab(vm);
      default:
        return _buildIdentityCardSubTab(vm);
    }
  }

  // ── Sub-Tab 0: Identity Card ───────────────────────────────────────────────

  Widget _buildIdentityCardSubTab(_ProfileViewModel vm) {
    final playerName = _nameController.text.isNotEmpty ? _nameController.text : 'لاعب كوتشينة';
    final estStats = vm.stats.estimationStats;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Flippable Player Identity Card with Native Sharing
              PlayerIdentityCard(
                playerName: playerName,
                avatarUrl: vm.currentPhoto,
                stats: estStats,
                profile: vm.personalityProfile,
                config: vm.cardConfig,
                onConfigChanged: _handleCardConfigChanged,
              ),

              const SizedBox(height: 16),

              // 2. Avatar & Name Editor Box
              _buildAvatarAndNameSection(vm),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-Tab 1: Playstyle & Personality ─────────────────────────────────────

  Widget _buildPlaystylePersonalitySubTab(_ProfileViewModel vm) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tactical Personality Profile Intelligence Card
              _buildPersonalityIntelligenceCard(vm.personalityProfile),

              const SizedBox(height: 20),

              // 10 Dimensions Radar / Bars
              _buildSectionHeader('أبعاد ومؤشرات أسلوب اللعب (0–100)', Icons.bar_chart_rounded, const Color(0xFF38BDF8)),
              const SizedBox(height: 12),
              PlaystyleRadarView(metrics: vm.personalityProfile.metrics),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-Tab 2: Match Stats ─────────────────────────────────────────────────

  Widget _buildMatchStatsSubTab(_ProfileViewModel vm) {
    final estStats = vm.stats.estimationStats;
    final totalGames = estStats.gamesPlayed > 0 ? estStats.gamesPlayed : vm.stats.totalMatches;
    final totalWins = estStats.gamesPlayed > 0 ? estStats.gamesWon : vm.stats.wins;
    final winRate = totalGames > 0
        ? ((totalWins / totalGames) * 100).toStringAsFixed(1)
        : '0.0';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Accuracy Metric Card
              _buildDeclarationAccuracyHeroCard(vm.stats.estimationStats),

              const SizedBox(height: 20),

              // Section 1: Match Performance & Win Streaks
              _buildSectionHeader('أداء المباريات والسلاسل', Icons.military_tech_rounded, AppTheme.gold),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'إجمالي الانتصارات',
                      value: '$totalWins',
                      icon: Icons.emoji_events_rounded,
                      color: AppTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'المباريات الملعوبة',
                      value: '$totalGames',
                      icon: Icons.style_rounded,
                      color: AppTheme.mintSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'نسبة الفوز',
                      value: '$winRate%',
                      icon: Icons.pie_chart_rounded,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'أطول سلسلة فوز',
                      value: '${estStats.longestWinningStreak}',
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFFF7043),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildWideStatCard(
                title: 'أفضل ريمونتادا (تعويض الفارق)',
                value: estStats.bestComeback > 0 ? '+${estStats.bestComeback} نقطة' : '—',
                icon: Icons.replay_circle_filled_rounded,
                color: const Color(0xFFAB47BC),
                subtitle: 'أكبر فارق نقاط تم تعويضه خلال الجولات لتحقيق المركز الأول',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'ريمونتادا كبرى (4th→1st)',
                      value: '${estStats.majorComebacks}',
                      icon: Icons.whatshot_rounded,
                      color: const Color(0xFFFF5722),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'ريمونتادا الجولة الأخيرة',
                      value: '${estStats.finalRoundComebacks}',
                      icon: Icons.military_tech_rounded,
                      color: AppTheme.gold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section 2: Rounds, Tricks & Declarations
              _buildSectionHeader('الجولات والتقديرات', Icons.psychology_rounded, AppTheme.mintSoft),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'إجمالي الجولات',
                      value: '${estStats.totalRounds}',
                      icon: Icons.sync_rounded,
                      color: const Color(0xFF42A5F5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'إجمالي اللمّات',
                      value: '${estStats.totalTricks}',
                      icon: Icons.layers_rounded,
                      color: const Color(0xFF26A69A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'متوسط التصريح',
                      value: estStats.totalRounds > 0 ? estStats.averageDeclaredTricks.toStringAsFixed(1) : '—',
                      icon: Icons.record_voice_over_rounded,
                      color: const Color(0xFFFFA726),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'متوسط اللم الفعلي',
                      value: estStats.totalRounds > 0 ? estStats.averageActualTricks.toStringAsFixed(1) : '—',
                      icon: Icons.pan_tool_alt_rounded,
                      color: const Color(0xFF66BB6A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'تقديرات دقيقة (ناجحة)',
                      value: '${estStats.perfectEstimates}',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'تصريحات فاشلة',
                      value: '${estStats.failedDeclarations}',
                      icon: Icons.cancel_rounded,
                      color: const Color(0xFFEF5350),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section 3: Bidding & High Scores
              _buildSectionHeader('المزايدات والأرقام القياسية', Icons.stars_rounded, AppTheme.goldLight),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'أعلى مزايدة ناجحة',
                      value: estStats.highestSuccessfulBid > 0 ? '${estStats.highestSuccessfulBid}' : '—',
                      icon: Icons.gavel_rounded,
                      color: AppTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'أعلى تصريح ناجح',
                      value: estStats.highestSuccessfulDeclaration > 0 ? '${estStats.highestSuccessfulDeclaration}' : '—',
                      icon: Icons.flag_rounded,
                      color: const Color(0xFF29B6F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'أعلى سكور بجولة',
                      value: estStats.highestScoreInOneRound != 0
                          ? (estStats.highestScoreInOneRound > 0
                              ? '+${estStats.highestScoreInOneRound}'
                              : '${estStats.highestScoreInOneRound}')
                          : (vm.stats.maxScore != 0 ? '${vm.stats.maxScore}' : '—'),
                      icon: Icons.arrow_circle_up_rounded,
                      color: const Color(0xFF66BB6A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'أقل سكور بجولة',
                      value: estStats.lowestScoreInOneRound != 0 ? '${estStats.lowestScoreInOneRound}' : '—',
                      icon: Icons.arrow_circle_down_rounded,
                      color: const Color(0xFFE57373),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-Tab 3: Account & Rank Tier ─────────────────────────────────────────

  Widget _buildAccountAndTierSubTab(_ProfileViewModel vm) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Google Account & Cloud Progression Card
              Consumer<AuthService>(
                builder: (context, auth, _) => _buildGoogleAuthCard(auth),
              ),

              const SizedBox(height: 20),

              // Rank Tiers Progression Section
              _buildSectionHeader('خارطة الرتب والمستويات', Icons.military_tech_rounded, AppTheme.gold),
              const SizedBox(height: 12),
              ...RankTier.allTiers.map((tier) {
                final isCurrent = AuthService.instance.currentProfile?.rankTier.type == tier.type;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrent ? tier.primaryColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent ? tier.primaryColor : Colors.white12,
                      width: isCurrent ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(tier.badgeEmoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier.titleAr,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: tier.primaryColor,
                              ),
                            ),
                            Text(
                              tier.maxLevel >= 9999
                                  ? 'المستوى ${tier.minLevel}+'
                                  : 'المستويات ${tier.minLevel} - ${tier.maxLevel}',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tier.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'رتبتك الحالية',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.navyDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar & Name Quick Box ────────────────────────────────────────────────

  Widget _buildAvatarAndNameSection(_ProfileViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        borderRadius: 20,
        borderColor: AppTheme.gold.withValues(alpha: 0.25),
        fillColor: AppTheme.navyDark.withValues(alpha: 0.6),
      ),
      child: Row(
        children: [
          // Avatar with quick change overlay
          GestureDetector(
            onTap: _openAvatarPicker,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold, width: 2),
                  ),
                  child: PlayerAvatar(
                    photoData: vm.currentPhoto,
                    size: 56,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 12,
                    color: AppTheme.navyDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Name and Edit Action
          Expanded(
            child: !vm.isEditingName
                ? Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text.isNotEmpty ? _nameController.text : 'لاعب كوتشينة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.cream,
                              ),
                            ),
                            Text(
                              'اضغط على زر التعديل لتغيير اسمك',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          vm.setEditingName(true);
                          _nameFocus.requestFocus();
                        },
                        icon: const Icon(Icons.edit_rounded, color: AppTheme.gold, size: 20),
                        tooltip: 'تعديل الاسم',
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'اكتب اسمك هنا...',
                            hintStyle: GoogleFonts.cairo(color: Colors.white38, fontSize: 13),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.gold),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.gold, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: vm.isSavingName ? null : _saveName,
                        icon: vm.isSavingName
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 26),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityIntelligenceCard(PlayerPersonalityProfile profile) {
    final primary = profile.primaryArchetype;
    final secondary = profile.secondaryArchetype;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primary.primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.primaryColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Evolution Alert Banner if evolved
          if (profile.hasEvolved) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تطور أسلوب اللعب التكتيكي! 🔥',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          profile.evolutionMessage,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Archetype Header Banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: primary.primaryColor, width: 1.5),
                ),
                child: Text(primary.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          primary.titleAr,
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: primary.primaryColor),
                          ),
                          child: Text(
                            'النمط الأساسي',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primary.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      primary.descriptionAr,
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Secondary Archetype
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Text(secondary.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'النمط الثانوي المساعد: ',
                  style: GoogleFonts.cairo(fontSize: 11.5, color: Colors.white60),
                ),
                Text(
                  secondary.titleAr,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: secondary.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Strengths & Weaknesses
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Strengths
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            'نقاط القوة التكتيكية',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...profile.strengths.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $s',
                              style: GoogleFonts.cairo(fontSize: 11, color: Colors.white),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Weaknesses / Growth Areas
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up_rounded, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Text(
                            'فرص التطوير والتحسين',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...profile.weaknesses.map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $w',
                              style: GoogleFonts.cairo(fontSize: 11, color: Colors.white),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Tactical Coaching Tip Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded, color: AppTheme.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'النصيحة الذهبية لأسلوبك:',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.recommendation,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Declaration Accuracy Card ─────────────────────────────────────────

  Widget _buildDeclarationAccuracyHeroCard(EstimationStatistics stats) {
    final accuracy = stats.totalDeclarations > 0 ? stats.declarationAccuracy : 0.0;
    final accuracyStr = accuracy.toStringAsFixed(1);
    final ratio = accuracy / 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B2A4A),
            AppTheme.navyDark,
            const Color(0xFF0F1E36),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                ),
                child: const Text('🎯', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'دقة التقدير',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.cream,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'المعيار الذهبي',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.goldLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'نسبة إصابة التقدير الدقيق من إجمالي الجولات',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppTheme.steelBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$accuracyStr%',
                style: GoogleFonts.cairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🎯 تقديرات دقيقة: ${stats.perfectEstimates}',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              Text(
                'إجمالي التصريحات: ${stats.totalDeclarations}',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppTheme.cream,
          ),
        ),
      ],
    );
  }

  Widget _buildWideStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.glassDecoration(
        borderRadius: 20,
        borderColor: color.withValues(alpha: 0.3),
        fillColor: AppTheme.navyDark.withValues(alpha: 0.6),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.cream,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    color: AppTheme.steelBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Google Auth & Cloud Sync Card ──────────────────────────────────────────

  Widget _buildGoogleAuthCard(AuthService auth) {
    final isAuth = auth.isAuthenticated;
    final profile = auth.currentProfile;

    if (!isAuth || profile == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navyDark.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: AppTheme.gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حفظ التقدم السحابي',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cream,
                        ),
                      ),
                      Text(
                        'اربط حسابك بحساب Google لمزامنة مستواك ونقاط الخبرة XP',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppTheme.steelBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _handleGoogleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cream,
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppTheme.navyDark,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.network(
                            'https://lh3.googleusercontent.com/COxitqgJr1sJnIDe8-jiKhxDx1FrYbtRHKJ9ztnGKOUJGpgq-NxjqbNA6cKoooVLmQI',
                            width: 22,
                            height: 22,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.account_circle_rounded,
                              size: 22,
                              color: AppTheme.navyDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'تسجيل الدخول عبر Google',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navyDark,
                                  height: 1.2,
                                ),
                              ),
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

    // Authenticated Profile State
    final levelProgress = profile.levelProgress;
    final currentLevelXp = profile.xp - profile.currentLevelBaseXp;
    final neededLevelXp = profile.nextLevelTargetXp - profile.currentLevelBaseXp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: profile.rankTier.primaryColor.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: profile.rankTier.primaryColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Account Info & Sign Out
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.username,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cream,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: AppTheme.gold, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                'المستوى ${profile.level}',
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      profile.email,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppTheme.steelBlue,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: auth.isLoading ? null : _handleGoogleSignOut,
                icon: const Icon(Icons.logout_rounded, color: Colors.white60, size: 18),
                tooltip: 'تسجيل الخروج',
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Rank Tier Display & Tiers Info Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RankTierBadge(
                tier: profile.rankTier,
                level: profile.level,
                onTap: _showRankTiersDialog,
              ),
              InkWell(
                onTap: _showRankTiersDialog,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'دليل الرتب',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.gold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.gold),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // XP Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'نقاط الخبرة (XP)',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.steelBlue,
                ),
              ),
              Text(
                '${profile.xp} / ${profile.nextLevelTargetXp} XP',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(profile.rankTier.primaryColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'باقي ${neededLevelXp - currentLevelXp} XP للوصول إلى المستوى ${profile.level + 1}',
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.glassDecoration(
        borderRadius: 20,
        borderColor: color.withValues(alpha: 0.25),
        fillColor: AppTheme.navyDark.withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppTheme.steelBlue,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.cream,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Match History ───────────────────────────────────────────────────

  Widget _buildHistoryTab(_ProfileViewModel vm) {
    final isAuth = AuthService.instance.isAuthenticated;
    final list = vm.filteredHistory;

    return Column(
      children: [
        // Mode Selector Pills
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  label: '♠️ إستميشن',
                  isSelected: vm.selectedModeFilter == 0,
                  onTap: () => vm.setModeFilter(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterChip(
                  label: '🔥 مود الـ 99',
                  isSelected: vm.selectedModeFilter == 1,
                  onTap: () => vm.setModeFilter(1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // History Content
        Expanded(
          child: !isAuth
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 54,
                          color: AppTheme.gold.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'سجل المباريات متاح فقط للحسابات المسجلة',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            color: AppTheme.cream,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'سجّل الدخول باستخدام حساب Google لحفظ سجل مبارياتك ومزامنتها سحابياً.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            color: AppTheme.steelBlue,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            vm.setTab(0);
                          },
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: Text(
                            'الانتقال لتسجيل الدخول',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.navyDark,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 54,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد مباريات مسجلة بعد',
                            style: GoogleFonts.cairo(
                              color: AppTheme.steelBlue,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length > 20 ? 20 : list.length,
                      itemBuilder: (context, index) {
                        return _ExpandableMatchCard(
                          item: list[index],
                          currentUserName: _nameController.text.trim(),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.gold.withValues(alpha: 0.18) : AppTheme.navyDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.gold : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? AppTheme.goldLight : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── Tab 2: Settings & Controls ─────────────────────────────────────────────

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Audio & SFX Group
          _buildSettingsCard(
            title: 'المؤثرات الصوتية والاهتزاز',
            icon: Icons.volume_up_rounded,
            accentColor: AppTheme.gold,
            children: [
              // Sound Toggle
              _buildSettingSwitch(
                title: 'المؤثرات الصوتية (SFX)',
                subtitle: 'أصوات رمي البطاقات وسحب الأكلات',
                value: _settings.sfxEnabled,
                onChanged: (val) {
                  _settings.setSfxEnabled(val);
                  if (val) AudioService.instance.playCard();
                },
              ),

              if (_settings.sfxEnabled) ...[
                const SizedBox(height: 12),
                // Volume Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Row(
                    children: [
                      Icon(Icons.volume_mute_rounded, color: AppTheme.steelBlue.withValues(alpha: 0.7), size: 18),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.gold,
                            inactiveTrackColor: AppTheme.surface2,
                            thumbColor: AppTheme.cream,
                            overlayColor: AppTheme.gold.withValues(alpha: 0.2),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _settings.sfxVolume,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (val) => _settings.setSfxVolume(val),
                            onChangeEnd: (_) => AudioService.instance.playCard(),
                          ),
                        ),
                      ),
                      const Icon(Icons.volume_up_rounded, color: AppTheme.gold, size: 18),
                    ],
                  ),
                ),
              ],

              const Divider(color: Colors.white12, height: 24),

              // Haptics Toggle
              _buildSettingSwitch(
                title: 'الاهتزاز التفاعلي (Haptics)',
                subtitle: 'اهتزاز لطيف عند الضغط ولعب البطاقات',
                value: _settings.hapticsEnabled,
                onChanged: (val) {
                  _settings.setHapticsEnabled(val);
                  if (val) AudioService.instance.playCard();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // In-App Updates Tile
          const UpdateCheckTile(),

          const SizedBox(height: 16),

          // App Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassDecoration(
              borderRadius: 18,
              borderColor: Colors.white12,
              fillColor: AppTheme.navyDark.withValues(alpha: 0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'كوتشينة مالتيبلاير',
                  style: GoogleFonts.cairo(
                    color: AppTheme.cream,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'إصدار الإنتاج الرسمي 2026',
                  style: GoogleFonts.cairo(
                    color: AppTheme.steelBlue,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassDecoration(
        borderRadius: 22,
        borderColor: accentColor.withValues(alpha: 0.25),
        fillColor: AppTheme.navyDark.withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cream,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cream,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.cairo(
                  fontSize: 11.5,
                  color: AppTheme.steelBlue,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppTheme.gold,
          activeTrackColor: AppTheme.gold.withValues(alpha: 0.4),
          inactiveThumbColor: AppTheme.steelBlue,
          inactiveTrackColor: AppTheme.surface2,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ── Tab 3: Interactive Game Guides ─────────────────────────────────────────

  Widget _buildGuidesTab(_ProfileViewModel vm) {
    return Column(
      children: [
        // Mode Sub-Tab Switcher (Estimation vs 99)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  label: '♠️ دليل الإستميشن',
                  isSelected: vm.selectedGuideSubTab == 0,
                  onTap: () => vm.setGuideSubTab(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterChip(
                  label: '🔥 دليل مود الـ 99',
                  isSelected: vm.selectedGuideSubTab == 1,
                  onTap: () => vm.setGuideSubTab(1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: vm.selectedGuideSubTab == 0
              ? _buildEstimationGuideList()
              : _buildNinetyNineGuideList(),
        ),
      ],
    );
  }

  Widget _buildEstimationGuideList() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildGuideSection(
          title: '♠️ تسلسل اللعبة وقوة الألوان',
          color: AppTheme.gold,
          bullets: [
            '• تلعب بـ 4 لاعبين، وكل لاعب يحصل على 13 كارت في كل جولة.',
            '• ترتيب قوة الحكم: سانز (بلا لون) > سبيد ♠ > هارت ♥ > كارو ♦ > تريفل ♣.',
            '• في عقد "السانز" لا يوجد كارت حكم، وأعلى كارت من لون الأكلة يفوز دائماً.',
            '• ترتيب قوة الكروت: A > K > Q > J > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2.',
          ],
        ),
        const SizedBox(height: 12),
        _buildGuideSection(
          title: '👑 المزاد والتصريح (Declarations)',
          color: AppTheme.mintSoft,
          bullets: [
            '• المزاد يبدأ من 4 لمات إلى 13 لمة.',
            '• الداش كول (Dash Call): إعلان طلب 0 أكلات قبل بدء المزاد بنقاط مضاعفة (+33/+25).',
            '• سقف الكولر: لا يجوز لأي لاعب طلب رقم أعلى من صاحب المزاد.',
            '• ممنوع الـ 13: اللاعب الأخير يُمنع من طلب الرقم الذي يجعل مجموع اللمات = 13.',
            '• الريسك (Risk): جعل مجموع الأكلات الأندر ≤ 11 يمنح بونص ريسك +10 عند النجاح.',
          ],
        ),
        const SizedBox(height: 12),
        _buildGuideSection(
          title: '🎯 قانون اتباع اللون (Follow Suit)',
          color: AppTheme.playerRed,
          bullets: [
            '• إجباري: يجب عليك لعب نفس لون الكارت المقصوص إن كان في يدك.',
            '• إذا لم تكن تمتلك من نفس اللون: يحق لك القطع بالحكم أو رمي كارت من لون آخر.',
          ],
        ),
        const SizedBox(height: 12),
        _buildGuideSection(
          title: '🏆 احتساب النقاط والبونصات',
          color: const Color(0xFF4CAF50),
          bullets: [
            '• النجاح: عدد اللمات + رقم الجولة الحالي + البونصات (كولر +10، معاها +10، ريسك +10).',
            '• الفشل: - (الفرق بين توقعك والأكلات الفعلية) - رقم الجولة - 10 عقوبة.',
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildNinetyNineGuideList() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildGuideSection(
          title: '🔥 فكرة مود الـ 99 والموت المفاجئ',
          color: const Color(0xFFEF4444),
          bullets: [
            '• يدعم من 2 إلى 7 لاعبين معاً في نفس الجولة.',
            '• يبدأ كل لاعب بـ 3 بطاقات في يده.',
            '• يلعب كل لاعب بطاقة تضيف لقيمة "الأرض" ويسحب فوراً بطاقة بديلة.',
            '• من يضطر لجعل الأرض تتجاوز 99 يخسر الجولة فوراً! 💥',
          ],
        ),
        const SizedBox(height: 12),
        _buildGuideSection(
          title: '🃏 تأثيرات البطاقات الخاصة',
          color: AppTheme.gold,
          bullets: [
            '• K (الشايب): يجعل الأرض 99 مباشرة، أو +0 إذا كانت 99 بالفعل.',
            '• Q (البنت): تضيف +10 إلى الأرض (بحد أقصى 99).',
            '• J (الولد): يطرح -10 من الأرض (منقذ أساسي عند الـ 99!).',
            '• 10 (العشرة): تضيف +10 أو تطرح -10 حسب اختيارك.',
            '• 4 و 7: كروت أمان ممتازة بقيمة +0 لا تزيد الأرض.',
            '• باقي الأرقام والآس: تضيف قيمتها الرقمية المباشرة (A = 1).',
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGuideSection({
    required String title,
    required Color color,
    required List<String> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        borderRadius: 20,
        borderColor: color.withValues(alpha: 0.3),
        fillColor: AppTheme.navyDark.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cream,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                b,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expandable Match Record Card ─────────────────────────────────────────────

class _ExpandableMatchCard extends StatefulWidget {
  final MatchRecord item;
  final String currentUserName;

  const _ExpandableMatchCard({
    required this.item,
    required this.currentUserName,
  });

  @override
  State<_ExpandableMatchCard> createState() => _ExpandableMatchCardState();
}

class _ExpandableMatchCardState extends State<_ExpandableMatchCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isWon = item.winnerName == widget.currentUserName.trim();
    final color = isWon ? const Color(0xFF4CAF50) : AppTheme.gold;
    String formattedDate = item.date;
    try {
      final dt = DateTime.parse(item.date);
      formattedDate = '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.glassDecoration(
        borderRadius: 18,
        borderColor: _isExpanded
            ? color.withValues(alpha: 0.5)
            : color.withValues(alpha: 0.25),
        fillColor: AppTheme.navyDark.withValues(alpha: 0.6),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          onExpansionChanged: (exp) {
            AudioService.instance.playCard();
            setState(() => _isExpanded = exp);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              isWon ? 'فوز 🏆' : 'مباراة',
              style: GoogleFonts.cairo(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            item.gameType == 'ninety_nine'
                ? 'مباراة 99 سريعة'
                : 'مباراة إستميشن كلاسيك',
            style: GoogleFonts.cairo(
              color: AppTheme.cream,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الفائز: ${item.winnerName} (${item.winnerScore} نقطة)',
                style: GoogleFonts.cairo(
                  color: AppTheme.steelBlue,
                  fontSize: 11.5,
                ),
              ),
              Text(
                formattedDate,
                style: GoogleFonts.cairo(
                  color: Colors.white38,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          trailing: AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: color,
              size: 24,
            ),
          ),
          children: [
            const Divider(color: Colors.white12, height: 16),
            if (item.players.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'لا توجد تفاصيل إضافية للاعبين في هذه المباراة',
                  style: GoogleFonts.cairo(color: AppTheme.steelBlue, fontSize: 12),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: item.players.map((p) {
                    final isSelf = p.name == widget.currentUserName.trim();
                    final isTopWinner = p.name == item.winnerName;

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: item.players.last == p
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (p.rankTitle.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isTopWinner
                                    ? AppTheme.gold.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.rankTitle,
                                style: GoogleFonts.cairo(
                                  color: isTopWinner ? AppTheme.gold : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  p.name,
                                  style: GoogleFonts.cairo(
                                    color: isSelf ? AppTheme.goldLight : Colors.white,
                                    fontWeight: isSelf ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isSelf) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.gold.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'أنت',
                                      style: GoogleFonts.cairo(
                                        color: AppTheme.gold,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${p.score} نقطة',
                            style: GoogleFonts.cairo(
                              color: isTopWinner ? AppTheme.gold : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}