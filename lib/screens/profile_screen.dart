// lib/screens/profile_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/widgets/player_avatar.dart';
import '../widgets/update_check_tile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();

  String _currentPhoto = ProfileService.presetAvatars.first.id;
  PlayerStats _stats = PlayerStats.empty();
  List<MatchRecord> _allHistory = [];
  bool _isLoading = true;
  bool _isSavingName = false;
  int _currentPage = 0;
  static const int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    final name = await ProfileService.getProfileName();
    final photo = await ProfileService.getProfilePhoto();
    final stats = await ProfileService.getProfileStats(name);
    final aHistory = name.isNotEmpty
        ? await ProfileService.getPlayerHistory(name)
        : await HistoryService.getHistory();

    if (mounted) {
      setState(() {
        _nameController.text = name;
        _currentPhoto = photo;
        _stats = stats;
        _allHistory = aHistory;
        _isLoading = false;
        _currentPage = 0;
      });
    }
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      SnackbarHelper.showError(context, 'يرجى إدخال اسم للاحتفاظ به', title: 'تنبيه');
      return;
    }

    setState(() => _isSavingName = true);
    await ProfileService.saveProfileName(newName);
    final stats = await ProfileService.getProfileStats(newName);

    if (mounted) {
      setState(() {
        _stats = stats;
        _isSavingName = false;
      });
      SnackbarHelper.showSuccess(context, 'تم حفظ الاسم بنجاح', title: 'تم الحفظ');
    }
  }

  Future<void> _selectAvatar(String photoData) async {
    await ProfileService.saveProfilePhoto(photoData);
    if (mounted) {
      setState(() {
        _currentPhoto = photoData;
      });
      SnackbarHelper.showSuccess(context, 'تم تحديث الصورة الشخصية', title: 'تم الحفظ');
    }
  }

  void _openAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'اختر صورة الملف الشخصي',
                    style: GoogleFonts.alexandria(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mintSoft,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Preset Avatars Grid
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                      ),
                      itemCount: ProfileService.presetAvatars.length,
                      itemBuilder: (context, index) {
                        final avatar = ProfileService.presetAvatars[index];
                        final isSelected = _currentPhoto == avatar.id;

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _selectAvatar(avatar.id);
                          },
                          child: Container(
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
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Gallery Upload Button
                  ElevatedButton.icon(
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
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                    label: Text(
                      'اختيار من المعرض',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceCard,
                      foregroundColor: AppTheme.accentLight,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.white12),
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Custom AppBar ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _nameController.text.isNotEmpty ? _nameController.text : 'الملف الشخصي',
                      style: GoogleFonts.alexandria(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mintSoft,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.gold),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header Card (Avatar + Name Edit) ─────────
                        _buildHeaderCard(),
                        const SizedBox(height: 20),

                        // ── Statistics Overview Grid ─────────────────
                        _buildStatsSection(),
                        const SizedBox(height: 20),

                        // ── Ranks Breakdown Badge Section ─────────────
                        _buildRanksSection(),
                        const SizedBox(height: 24),

                        // ── Match History Tabs ────────────────────────
                        _buildHistorySection(),
                        const SizedBox(height: 24),

                        // ── Update Checker ────────────────────────────
                        const UpdateCheckTile(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF253070), AppTheme.navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Avatar with Edit Button Overlay
          GestureDetector(
            onTap: _openAvatarPicker,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                PlayerAvatar(photoData: _currentPhoto, size: 96),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.accentBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Name Input Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    color: AppTheme.mintSoft,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'أدخل اسمك...',
                    hintStyle: GoogleFonts.cairo(color: Colors.white38),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.accentLight),
                    filled: true,
                    fillColor: AppTheme.navyDark.withValues(alpha: 0.7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.accentBlue, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isSavingName ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSavingName
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'حفظ',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات الأداء 📊',
          style: GoogleFonts.alexandria(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                title: 'المباريات',
                value: '${_stats.totalMatches}',
                icon: Icons.sports_esports_rounded,
                color: AppTheme.accentLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                title: 'الانتصارات',
                value: '${_stats.wins}',
                icon: Icons.emoji_events_rounded,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                title: 'نسبة الفوز',
                value: '${_stats.winRate.toStringAsFixed(0)}%',
                icon: Icons.pie_chart_rounded,
                color: AppTheme.mintSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                title: 'معدل النقاط',
                value: _stats.avgScore.toStringAsFixed(1),
                icon: Icons.analytics_rounded,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                title: 'أعلى رصيد',
                value: '${_stats.maxScore}',
                icon: Icons.star_rounded,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                title: 'إجمالي النقاط',
                value: '${_stats.totalScore}',
                icon: Icons.score_rounded,
                color: Colors.purpleAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.alexandria(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRanksSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سجل الألقاب والترتيب 👑',
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.mintSoft,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRankBadge('كينج 👑', '${_stats.kingCount}', AppTheme.gold),
              _buildRankBadge('صب كينج 🥈', '${_stats.subKingCount}', Colors.blueGrey.shade200),
              _buildRankBadge('صب كوز 🥉', '${_stats.subKozCount}', Colors.amber.shade700),
              _buildRankBadge('كوز 🤡', '${_stats.kozCount}', AppTheme.errorRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            count,
            style: GoogleFonts.alexandria(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    final totalPages = (_allHistory.length / _itemsPerPage).ceil();
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < _allHistory.length)
        ? startIndex + _itemsPerPage
        : _allHistory.length;
    
    final currentRecords = _allHistory.isNotEmpty
        ? _allHistory.sublist(startIndex, endIndex)
        : <MatchRecord>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل المباريات 📜',
          style: GoogleFonts.alexandria(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(height: 12),
        _buildHistoryList(currentRecords, emptyMsg: 'لا توجد مباريات مسجلة'),
        if (totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: _currentPage > 0 ? AppTheme.gold : Colors.white24,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${_currentPage + 1} / $totalPages',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: _currentPage < totalPages - 1 ? AppTheme.gold : Colors.white24,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryList(List<MatchRecord> records, {required String emptyMsg}) {
    if (records.isEmpty) {
      return Center(
        child: Text(
          emptyMsg,
          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 15),
        ),
      );
    }

    final pName = _nameController.text.trim().toLowerCase();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final isWinner = record.winnerName.trim().toLowerCase() == pName;
        final date = DateTime.tryParse(record.date);
        final dateStr = date != null
            ? '${date.year}/${date.month}/${date.day} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
            : record.date;

        return Card(
          color: AppTheme.surfaceCard,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isWinner ? AppTheme.gold.withValues(alpha: 0.5) : Colors.white12,
            ),
          ),
          child: ExpansionTile(
            iconColor: AppTheme.gold,
            collapsedIconColor: AppTheme.accentLight,
            title: Row(
              children: [
                Text(
                  'الفائز: ${record.winnerName}',
                  style: GoogleFonts.cairo(
                    color: isWinner ? AppTheme.gold : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isWinner) ...[
                  const SizedBox(width: 6),
                  const Text('👑', style: TextStyle(fontSize: 16)),
                ],
              ],
            ),
            subtitle: Text(
              '$dateStr • ${record.winnerScore} نقطة',
              style: GoogleFonts.cairo(color: AppTheme.textSecondary, fontSize: 12),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black26,
                child: Column(
                  children: record.players.map((p) {
                    final isCurrentPlayer = p.name.trim().toLowerCase() == pName;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${p.name} ${p.rankTitle.isNotEmpty ? "(${p.rankTitle})" : ""}',
                            style: GoogleFonts.cairo(
                              color: isCurrentPlayer ? AppTheme.gold : Colors.white,
                              fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${p.score} نقطة',
                            style: GoogleFonts.alexandria(
                              color: isCurrentPlayer ? AppTheme.mintSoft : Colors.white70,
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
          ),
        );
      },
    );
  }
}
