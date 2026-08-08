// lib/screens/profile_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/widgets/player_avatar.dart';
import '../widgets/update_check_tile.dart';

// ---------------------------------------------------------------------------
// Local ChangeNotifier — owns all profile UI state so setState is never needed.
// Scoped only to ProfileScreen via ChangeNotifierProvider in its build method.
// ---------------------------------------------------------------------------
class _ProfileViewModel extends ChangeNotifier {
  String currentPhoto = ProfileService.presetAvatars.first.id;
  PlayerStats stats = PlayerStats.empty();
  List<MatchRecord> allHistory = [];
  bool isLoading = true;
  bool isSavingName = false;
  bool isEditingName = false;
  int currentPage = 0;
  int currentTab = 0; // 0 = overview, 1 = history
  int selectedModeFilter = 0; // 0 = Estimation, 1 = 99 Mode

  void setLoading(bool v) { isLoading = v; notifyListeners(); }

  void updateAfterLoad({
    required String photo,
    required PlayerStats stats,
    required List<MatchRecord> history,
  }) {
    currentPhoto = photo;
    this.stats = stats;
    allHistory = history;
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

  void setSavingName(bool v) { isSavingName = v; notifyListeners(); }

  void setEditingName(bool v) { isEditingName = v; notifyListeners(); }

  void setPhoto(String photo) { currentPhoto = photo; notifyListeners(); }

  void setPage(int page) { currentPage = page; notifyListeners(); }

  void setTab(int tab) { currentTab = tab; currentPage = 0; notifyListeners(); }

  void setModeFilter(int filter) {
    selectedModeFilter = filter;
    currentPage = 0;
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
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  // All profile state lives in _ProfileViewModel — no setState ever called here.
  late final _vm = _ProfileViewModel();

  static const int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    _vm.setLoading(true);

    try {
      final name = await ProfileService.getProfileName().timeout(
        const Duration(seconds: 2),
        onTimeout: () => '',
      );
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

      if (mounted) {
        _nameController.text = name;
        _vm.updateAfterLoad(photo: photo, stats: stats, history: aHistory);
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Error loading profile data: $e');
      if (mounted) {
        _vm.setLoading(false);
      }
    }
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      SnackbarHelper.showError(context, 'يرجى إدخال اسم للاحتفاظ به', title: 'تنبيه');
      return;
    }

    _vm.setSavingName(true);
    await ProfileService.saveProfileName(newName);
    final stats = await ProfileService.getProfileStats(newName);

    if (mounted) {
      _vm.updateAfterSave(stats);
      _nameFocus.unfocus();
      SnackbarHelper.showSuccess(context, 'تم حفظ الاسم بنجاح', title: 'تم الحفظ');
    }
  }

  Future<void> _selectAvatar(String photoData) async {
    await ProfileService.saveProfilePhoto(photoData);
    if (mounted) {
      _vm.setPhoto(photoData);
      SnackbarHelper.showSuccess(context, 'تم تحديث الصورة الشخصية', title: 'تم الحفظ');
    }
  }

  void _openAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
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
                        'اختر هويتك الملكية',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mintSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 512,
                              maxHeight: 512,
                              imageQuality: 70,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              final base64String = base64Encode(bytes);
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                _selectAvatar(base64String);
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              SnackbarHelper.showError(context, 'حدث خطأ أثناء اختيار الصورة', title: 'عذراً');
                            }
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 20, color: AppTheme.accentLight),
                        label: Text(
                          'رفع صورة من المعرض',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppTheme.accentLight),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppTheme.accentBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
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
      child: Consumer<_ProfileViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
              child: SafeArea(
                bottom: false,
                child: vm.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.gold),
                      )
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _buildTopBar()),
                          SliverToBoxAdapter(child: _buildHeroHeader(vm)),
                          SliverToBoxAdapter(child: _buildTabSwitcher(vm)),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                            sliver: SliverToBoxAdapter(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.04),
                                      end: Offset.zero,
                                    ).animate(anim),
                                    child: child,
                                  ),
                                ),
                                child: vm.currentTab == 0
                                    ? _buildOverviewTab(vm)
                                    : _buildHistoryTab(vm),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            'الملف الشخصي',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white38,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  // ── Hero header: crown-ring avatar + inline editable name ─────────────────
  Widget _buildHeroHeader(_ProfileViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          GestureDetector(
            onTap: _openAvatarPicker,
            child: SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated win-rate ring — the screen's signature element.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: (vm.stats.winRate.clamp(0, 100)) / 100),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return SizedBox(
                        width: 132,
                        height: 132,
                        child: CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 4,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      );
                    },
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: (vm.stats.winRate.clamp(0, 100)) / 100),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return SizedBox(
                        width: 132,
                        height: 132,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 4,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
                        ),
                      );
                    },
                  ),
                  PlayerAvatar(photoData: vm.currentPhoto, size: 104),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.navyDark, width: 2.5),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildNameField(vm),
          const SizedBox(height: 6),
          Text(
            '${vm.stats.winRate.toStringAsFixed(0)}٪ نسبة الفوز',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.gold.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(_ProfileViewModel vm) {
    if (!vm.isEditingName) {
      return GestureDetector(
        onTap: () {
          _vm.setEditingName(true);
          Future.delayed(const Duration(milliseconds: 50), () => _nameFocus.requestFocus());
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_rounded, size: 15, color: Colors.white38),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _nameController.text.isNotEmpty ? _nameController.text : 'أضف اسمك',
                style: GoogleFonts.cairo(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mintSoft,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            autofocus: true,
            textAlign: TextAlign.center,
            onSubmitted: (_) => _saveName(),
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.mintSoft,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'اسمك...',
              hintStyle: GoogleFonts.cairo(color: Colors.white38, fontSize: 16),
              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accentBlue, width: 1.4),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.gold, width: 1.8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        vm.isSavingName
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2),
                ),
              )
            : GestureDetector(
                onTap: _saveName,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 16, color: AppTheme.navyDark),
                ),
              ),
      ],
    );
  }

  // ── Segmented tab switcher ─────────────────────────────────────────────
  Widget _buildTabSwitcher(_ProfileViewModel vm) {
    final tabs = ['نظرة عامة', 'سجل المباريات'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.navyDark.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = vm.currentTab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => _vm.setTab(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.accentBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppTheme.accentBlue.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[i],
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Overview tab: bento stat grid + royal court ranks ──────────────────
  Widget _buildOverviewTab(_ProfileViewModel vm) {
    return Column(
      key: const ValueKey('overview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBentoStats(vm),
        const SizedBox(height: 22),
        _buildRoyalCourt(vm),
        const SizedBox(height: 22),
        const UpdateCheckTile(),
      ],
    );
  }

  Widget _buildBentoStats(_ProfileViewModel vm) {
    return Column(
      children: [
        // Large highlight row: matches + wins side by side.
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _StatCard(
                title: 'إجمالي المباريات',
                value: '${vm.stats.totalMatches}',
                icon: Icons.style_rounded,
                color: AppTheme.accentLight,
                large: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _StatCard(
                title: 'الانتصارات',
                value: '${vm.stats.wins}',
                icon: Icons.emoji_events_rounded,
                color: AppTheme.gold,
                large: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'معدل النقاط',
                value: vm.stats.avgScore.toStringAsFixed(1),
                icon: Icons.analytics_rounded,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'أعلى رصيد',
                value: '${vm.stats.maxScore}',
                icon: Icons.trending_up_rounded,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'مجموع النقاط',
                value: '${vm.stats.totalScore}',
                icon: Icons.score_rounded,
                color: Colors.purpleAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoyalCourt(_ProfileViewModel vm) {
    final ranks = [
      (label: 'كينج', emoji: '👑', count: vm.stats.kingCount, color: AppTheme.rankGold),
      (label: 'صب كينج', emoji: '🥈', count: vm.stats.subKingCount, color: AppTheme.rankSilver),
      (label: 'صب كوز', emoji: '🥉', count: vm.stats.subKozCount, color: AppTheme.rankBronze),
      (label: 'كوز', emoji: '🤡', count: vm.stats.kozCount, color: AppTheme.rankLast),
    ];
    final total = ranks.fold<int>(0, (sum, r) => sum + r.count);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'البلاط الملكي',
                style: GoogleFonts.cairo(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mintSoft,
                ),
              ),
              const Spacer(),
              Text(
                '$total جولة',
                style: GoogleFonts.cairo(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Proportional rank bar — a single glanceable read of the player's
          // whole rank distribution, more informative than four flat badges.
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: ranks.where((r) => r.count > 0).map((r) {
                    return Expanded(
                      flex: r.count,
                      child: Container(color: r.color.withValues(alpha: 0.85)),
                    );
                  }).toList(),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(height: 10, color: Colors.white10),
            ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ranks.map((r) => _buildRankBadge(r.label, r.emoji, r.count, r.color)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(String label, String emoji, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 19)),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  // ── History tab ──────────────────────────────────────────────────────────
  Widget _buildHistoryTab(_ProfileViewModel vm) {
    final historyList = vm.filteredHistory;
    final totalPages = (historyList.length / _itemsPerPage).ceil();
    final startIndex = vm.currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < historyList.length)
        ? startIndex + _itemsPerPage
        : historyList.length;

    final currentRecords = historyList.isNotEmpty
        ? historyList.sublist(startIndex, endIndex)
        : <MatchRecord>[];

    return Column(
      key: const ValueKey('history'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Filter Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: Text('مود الاستميشن 🎴', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
              selected: vm.selectedModeFilter == 0,
              onSelected: (_) => vm.setModeFilter(0),
              selectedColor: AppTheme.accentBlue,
              backgroundColor: AppTheme.navyDark.withValues(alpha: 0.5),
              labelStyle: TextStyle(color: vm.selectedModeFilter == 0 ? Colors.white : Colors.white60),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('مود الـ 99 🔥', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
              selected: vm.selectedModeFilter == 1,
              onSelected: (_) => vm.setModeFilter(1),
              selectedColor: const Color(0xFFEF4444),
              backgroundColor: AppTheme.navyDark.withValues(alpha: 0.5),
              labelStyle: TextStyle(color: vm.selectedModeFilter == 1 ? Colors.white : Colors.white60),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (currentRecords.isEmpty)
          _buildEmptyHistory()
        else
          ...currentRecords.map((r) => _MatchTimelineCard(
                record: r,
                playerName: _nameController.text.trim(),
              )),
        if (totalPages > 1) ...[
          const SizedBox(height: 8),
          _buildPagination(vm, totalPages),
        ],
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 40, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            'لا توجد مباريات مسجلة بعد',
            style: GoogleFonts.cairo(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(_ProfileViewModel vm, int totalPages) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageArrow(
            icon: Icons.arrow_back_ios_new_rounded,
            enabled: vm.currentPage > 0,
            onTap: () => _vm.setPage(vm.currentPage - 1),
          ),
          const SizedBox(width: 14),
          Row(
            children: List.generate(totalPages, (i) {
              final isActive = i == vm.currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.gold : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(width: 14),
          _PageArrow(
            icon: Icons.arrow_forward_ios_rounded,
            enabled: vm.currentPage < totalPages - 1,
            onTap: () => _vm.setPage(vm.currentPage + 1),
          ),
        ],
      ),
    );
  }
}

// ── Reusable stat card ──────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool large;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: large ? 18 : 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: large ? 22 : 18),
          ),
          SizedBox(height: large ? 10 : 8),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: large ? 24 : 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: large ? 12.5 : 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Pagination arrow ─────────────────────────────────────────────────────
class _PageArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageArrow({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.navyDark.withValues(alpha: 0.7) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? Colors.white24 : Colors.white10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: enabled ? AppTheme.gold : Colors.white24),
      ),
    );
  }
}

// ── Timeline-style match card ────────────────────────────────────────────
class _MatchTimelineCard extends StatefulWidget {
  final MatchRecord record;
  final String playerName;

  const _MatchTimelineCard({required this.record, required this.playerName});

  @override
  State<_MatchTimelineCard> createState() => _MatchTimelineCardState();
}

class _MatchTimelineCardState extends State<_MatchTimelineCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final pName = widget.playerName.trim().toLowerCase();
    final isWinner = record.winnerName.trim().toLowerCase() == pName;
    final date = DateTime.tryParse(record.date);
    final dateStr = date != null
        ? '${date.year}/${date.month}/${date.day} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : record.date;

    final topScore = record.players.isNotEmpty
        ? record.players.map((p) => p.score).reduce((a, b) => a > b ? a : b)
        : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWinner ? AppTheme.gold.withValues(alpha: 0.45) : Colors.white12,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isWinner ? AppTheme.gold : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                record.winnerName,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  color: isWinner ? AppTheme.gold : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (isWinner) ...[
                              const SizedBox(width: 6),
                              const Text('👑', style: TextStyle(fontSize: 14)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dateStr,
                          style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${record.winnerScore}',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.mintSoft,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              color: Colors.black26,
              child: Column(
                children: record.players.map((p) {
                  final isCurrentPlayer = p.name.trim().toLowerCase() == pName;
                  final ratio = topScore > 0 ? (p.score / topScore).clamp(0.0, 1.0) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '${p.name}${p.rankTitle.isNotEmpty ? "  •  ${p.rankTitle}" : ""}',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  color: isCurrentPlayer ? AppTheme.gold : Colors.white70,
                                  fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            Text(
                              '${p.score}',
                              style: GoogleFonts.cairo(
                                color: isCurrentPlayer ? AppTheme.mintSoft : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 4,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation(
                              isCurrentPlayer ? AppTheme.gold : AppTheme.accentBlue.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}