// lib/screens/puzzles/puzzles_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/puzzle_models.dart';
import '../../services/puzzle_service.dart';
import '../../services/audio_service.dart';
import '../../theme/app_theme.dart';
import 'puzzle_solve_screen.dart';

class PuzzlesHomeScreen extends StatefulWidget {
  const PuzzlesHomeScreen({super.key});

  @override
  State<PuzzlesHomeScreen> createState() => _PuzzlesHomeScreenState();
}

class _PuzzlesHomeScreenState extends State<PuzzlesHomeScreen> {
  final PuzzleService _service = PuzzleService.instance;

  PuzzleCategory? _selectedCategory;
  PuzzleDifficulty? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _service.initialize();
  }

  void _openPuzzle(EstimationPuzzle puzzle, {bool isDaily = false}) async {
    HapticFeedback.selectionClick();
    AudioService.instance.playCard();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PuzzleSolveScreen(
          puzzleId: puzzle.id,
          isDaily: isDaily,
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PuzzleProgress>(
      valueListenable: _service.progressNotifier,
      builder: (context, progress, _) {
        final allPuzzles = _service.puzzles;
        final dailyPuzzle = _service.getDailyPuzzle();
        final isDailySolved = _service.isDailyPuzzleSolved();

        final filteredPuzzles = allPuzzles.where((p) {
          if (_selectedCategory != null && p.category != _selectedCategory) {
            return false;
          }
          if (_selectedDifficulty != null && p.difficulty != _selectedDifficulty) {
            return false;
          }
          return true;
        }).toList();

        final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

        return Scaffold(
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

              // Deep modern gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        AppTheme.deepNavy.withValues(alpha: 0.88),
                        AppTheme.deepNavy.withValues(alpha: 0.98),
                      ],
                      stops: const [0.0, 0.40, 1.0],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Top App Bar
                    _buildTopBar(context),

                    // Main Scrollable Area
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Stats Summary Bar (Streak, Solved, XP, Perfect)
                                _buildStatsBar(progress, allPuzzles.length),

                                const SizedBox(height: 14),

                                // Featured Daily Puzzle Hero Card
                                _buildDailyPuzzleCard(dailyPuzzle, isDailySolved, progress.dailyPuzzleStreak),

                                const SizedBox(height: 16),

                                // Category Filter Pills
                                _buildCategoryFilter(),

                                const SizedBox(height: 10),

                                // Difficulty Filter Pills
                                _buildDifficultyFilter(),

                                const SizedBox(height: 14),

                                // Section Title
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'قائمة الألغاز والتحديات (${filteredPuzzles.length})',
                                      style: GoogleFonts.cairo(
                                        color: AppTheme.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_selectedCategory != null || _selectedDifficulty != null) ...[
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedCategory = null;
                                            _selectedDifficulty = null;
                                          });
                                        },
                                        child: Text(
                                          'إعادة ضبط الفلتر ✕',
                                          style: GoogleFonts.cairo(
                                            color: AppTheme.gold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Puzzles Grid / List
                                _buildPuzzlesGrid(filteredPuzzles, progress, isLandscape),

                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.gold, size: 20),
                tooltip: 'رجوع',
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ألغاز الإستميشن',
                        style: GoogleFonts.cairo(
                          color: AppTheme.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF8B5CF6), width: 0.8),
                        ),
                        child: Text(
                          'Puzzle Mode 🧩',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFFA78BFA),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'تحديات تكتيكية منفصلة وسيناريوهات استراتيجية',
                    style: GoogleFonts.cairo(
                      color: AppTheme.steelBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats Summary Bar ──────────────────────────────────────────────────────

  Widget _buildStatsBar(PuzzleProgress progress, int totalPuzzles) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatPill(
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFF97316),
            label: 'الحماسة اليومية',
            value: '${progress.dailyPuzzleStreak} أيام',
          ),
          _buildStatDivider(),
          _buildStatPill(
            icon: Icons.extension_rounded,
            color: const Color(0xFF10B981),
            label: 'الألغاز المحلولة',
            value: '${progress.totalSolvedCount} / $totalPuzzles',
          ),
          _buildStatDivider(),
          _buildStatPill(
            icon: Icons.stars_rounded,
            color: const Color(0xFFA855F7),
            label: 'أداء مثالي 100%',
            value: '${progress.perfectCount}',
          ),
          _buildStatDivider(),
          _buildStatPill(
            icon: Icons.bolt_rounded,
            color: AppTheme.gold,
            label: 'إجمالي الـ XP',
            value: '${progress.totalXpEarned}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 28, color: Colors.white12);
  }

  Widget _buildStatPill({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 3),
            Text(
              value,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: AppTheme.steelBlue,
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Daily Puzzle Card ──────────────────────────────────────────────────────

  Widget _buildDailyPuzzleCard(EstimationPuzzle dailyPuzzle, bool isSolved, int streak) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4C1D95), // Vibrant purple
            Color(0xFF311042),
            Color(0xFF1E1B4B),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF472B6).withValues(alpha: 0.6),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF472B6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.psychology_alt_rounded, color: Color(0xFFF472B6), size: 20),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لغز اليوم (Daily Puzzle) 🧩',
                          style: GoogleFonts.cairo(
                            color: AppTheme.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'لغز موحد لجميع اللاعبين يومياً • مكافأة إضافية +25 XP',
                          style: GoogleFonts.cairo(
                            color: AppTheme.cream.withValues(alpha: 0.7),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isSolved) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'تم الحل اليوم ✅',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dailyPuzzle.title,
                          style: GoogleFonts.cairo(
                            color: AppTheme.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${dailyPuzzle.category.arabicTitle} • ${dailyPuzzle.difficulty.arabicLabel}',
                          style: GoogleFonts.cairo(
                            color: AppTheme.steelBlue,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _openPuzzle(dailyPuzzle, isDaily: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSolved ? Colors.white12 : const Color(0xFFF472B6),
                      foregroundColor: isSolved ? Colors.white70 : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isSolved ? 'مراجعة اللغز 👁️' : 'حل اللغز الآن 🔥',
                      style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold),
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

  // ── Category Filter ────────────────────────────────────────────────────────

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'الكل (جميع الأنماط)',
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          for (final cat in PuzzleCategory.values) ...[
            const SizedBox(width: 8),
            _buildFilterChip(
              label: '${cat.icon} ${cat.arabicTitle}',
              isSelected: _selectedCategory == cat,
              onTap: () => setState(() => _selectedCategory = cat),
              accentColor: cat.color,
            ),
          ],
        ],
      ),
    );
  }

  // ── Difficulty Filter ──────────────────────────────────────────────────────

  Widget _buildDifficultyFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'كل المستويات',
            isSelected: _selectedDifficulty == null,
            onTap: () => setState(() => _selectedDifficulty = null),
          ),
          for (final diff in PuzzleDifficulty.values) ...[
            const SizedBox(width: 8),
            _buildFilterChip(
              label: diff.arabicLabel,
              isSelected: _selectedDifficulty == diff,
              onTap: () => setState(() => _selectedDifficulty = diff),
              accentColor: diff.color,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final activeColor = accentColor ?? AppTheme.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white12,
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? activeColor : Colors.white70,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Puzzles Grid ───────────────────────────────────────────────────────────

  Widget _buildPuzzlesGrid(
    List<EstimationPuzzle> puzzles,
    PuzzleProgress progress,
    bool isLandscape,
  ) {
    if (puzzles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, color: Colors.white38, size: 48),
            const SizedBox(height: 8),
            Text(
              'لا توجد ألغاز تطابق هذا الفلتر',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (isLandscape) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 115,
        ),
        itemCount: puzzles.length,
        itemBuilder: (context, i) => _buildPuzzleCard(puzzles[i], progress),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: puzzles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildPuzzleCard(puzzles[i], progress),
    );
  }

  Widget _buildPuzzleCard(EstimationPuzzle puzzle, PuzzleProgress progress) {
    final isSolved = progress.isSolved(puzzle.id);
    final bestScore = progress.getBestScore(puzzle.id);
    final attempts = progress.getAttempts(puzzle.id);

    return InkWell(
      onTap: () => _openPuzzle(puzzle),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.navyDark.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSolved
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: isSolved ? 1.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category Icon Badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: puzzle.category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: puzzle.category.color.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                puzzle.category.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),

            const SizedBox(width: 12),

            // Title & Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          puzzle.title,
                          style: GoogleFonts.cairo(
                            color: AppTheme.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSolved) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.check_circle_rounded,
                          color: bestScore == 100 ? AppTheme.gold : const Color(0xFF10B981),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${puzzle.category.arabicTitle} • ${puzzle.difficulty.arabicLabel}',
                    style: GoogleFonts.cairo(
                      color: AppTheme.steelBlue,
                      fontSize: 11,
                    ),
                  ),
                  if (attempts > 0) ...[
                    Text(
                      'أفضل نتيجة: $bestScore نقطة ($attempts محاولات)',
                      style: GoogleFonts.cairo(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // XP Badge & Arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${puzzle.xpReward} XP',
                    style: GoogleFonts.cairo(
                      color: AppTheme.goldLight,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white38,
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
