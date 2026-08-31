// lib/screens/puzzles/puzzle_solve_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/puzzle_models.dart';
import '../../core/constants.dart';
import '../../core/models/card.dart';
import '../../services/puzzle_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/playing_card_widget.dart';
import '../../core/widgets/app_buttons.dart';
import 'package:estimation/core/icons/app_icons.dart';

class PuzzleSolveScreen extends StatefulWidget {
  final String puzzleId;
  final bool isDaily;

  const PuzzleSolveScreen({
    super.key,
    required this.puzzleId,
    this.isDaily = false,
  });

  @override
  State<PuzzleSolveScreen> createState() => _PuzzleSolveScreenState();
}

class _PuzzleSolveScreenState extends State<PuzzleSolveScreen> {
  final PuzzleService _service = PuzzleService.instance;

  EstimationPuzzle? _puzzle;
  String? _selectedOptionId;
  bool _isSubmitted = false;
  PuzzleResultQuality? _lastResult;
  bool _isEvaluating = false;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  void _loadPuzzle() {
    final p = _service.getPuzzleById(widget.puzzleId);
    setState(() {
      _puzzle = p;
      _selectedOptionId = null;
      _isSubmitted = false;
      _lastResult = null;
    });
  }

  void _onSelectOption(PuzzleOption option) {
    if (_isSubmitted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedOptionId = option.id;
    });
  }

  void _onSubmit() async {
    if (_puzzle == null || _selectedOptionId == null || _isSubmitted || _isEvaluating) {
      return;
    }

    final option = _puzzle!.options.firstWhere(
      (o) => o.id == _selectedOptionId,
      orElse: () => _puzzle!.options.first,
    );

    setState(() => _isEvaluating = true);

    final quality = await _service.submitAnswer(
      puzzle: _puzzle!,
      option: option,
      isDaily: widget.isDaily,
    );

    if (mounted) {
      setState(() {
        _isSubmitted = true;
        _lastResult = quality;
        _isEvaluating = false;
      });

      if (quality.isSuccessful) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _onRetry() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedOptionId = null;
      _isSubmitted = false;
      _lastResult = null;
    });
  }

  void _onNextPuzzle() {
    final allPuzzles = _service.puzzles;
    final currentIndex = allPuzzles.indexWhere((p) => p.id == widget.puzzleId);
    if (currentIndex != -1 && currentIndex + 1 < allPuzzles.length) {
      final nextPuz = allPuzzles[currentIndex + 1];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PuzzleSolveScreen(
            puzzleId: nextPuz.id,
            isDaily: false,
          ),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzle;

    if (puzzle == null) {
      return Scaffold(
        backgroundColor: AppTheme.deepNavy,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('اللغز غير موجود', style: GoogleFonts.cairo(color: Colors.white)),
        ),
        body: Center(
          child: Text(
            'لم يتم العثور على هذا اللغز.',
            style: GoogleFonts.cairo(color: Colors.white70),
          ),
        ),
      );
    }

    final isPortrait = MediaQuery.of(context).size.width < MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background wallpaper with dark overlay
          Positioned.fill(
            child: Image.asset(
              'assets/wallpapers/w1.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    AppTheme.deepNavy.withValues(alpha: 0.90),
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
                _buildTopBar(puzzle),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Context HUD (Round, Trump, Situation)
                            _buildContextHud(puzzle.context),

                            const SizedBox(height: 12),

                            // Player Hand Viewer
                            _buildHandViewer(puzzle.playerHand, isPortrait),

                            const SizedBox(height: 12),

                            // Scenario Prompt Card
                            _buildPromptCard(puzzle),

                            const SizedBox(height: 14),

                            // Interactive Options
                            _buildOptionsList(puzzle),

                            const SizedBox(height: 14),

                            // Submit Button (before submission)
                            if (!_isSubmitted) _buildSubmitButton(),

                            // Tactical Feedback & Result (after submission)
                            if (_isSubmitted) _buildFeedbackCard(puzzle),

                            const SizedBox(height: 24),
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
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(EstimationPuzzle puzzle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          AppIconButton(
            icon: AppIcons.arrowBackIosNew,
            color: AppTheme.gold,
            size: AppIconButtonSize.md,
            tooltip: 'رجوع',
            onTap: () => Navigator.pop(context),
          ),

          const SizedBox(width: 4),

          // Title & Category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (widget.isDaily) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEC4899), width: 0.8),
                        ),
                        child: Text(
                          'لغز اليوم 🧩',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFFF472B6),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        puzzle.title,
                        style: GoogleFonts.cairo(
                          color: AppTheme.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${puzzle.category.icon} ${puzzle.category.arabicTitle} • ${puzzle.difficulty.arabicLabel}',
                  style: GoogleFonts.cairo(
                    color: AppTheme.steelBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // XP Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(AppIcons.bolt, color: AppTheme.gold, size: 14),
                const SizedBox(width: 2),
                Text(
                  '+${puzzle.xpReward} XP',
                  style: GoogleFonts.cairo(
                    color: AppTheme.goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Context HUD ────────────────────────────────────────────────────────────

  Widget _buildContextHud(PuzzleContext ctx) {
    String trumpLabel = 'بدون';
    Color trumpColor = AppTheme.gold;
    if (ctx.trump != null) {
      if (ctx.trump == Trump.spade) {
        trumpLabel = 'سبيد ♠';
        trumpColor = AppTheme.accentLight;
      } else if (ctx.trump == Trump.heart) {
        trumpLabel = 'هارت ♥';
        trumpColor = AppTheme.suitRed;
      } else if (ctx.trump == Trump.diamond) {
        trumpLabel = 'كارو ♦';
        trumpColor = AppTheme.suitRed;
      } else if (ctx.trump == Trump.club) {
        trumpLabel = 'تريفل ♣';
        trumpColor = AppTheme.accentLight;
      } else if (ctx.trump == Trump.sans) {
        trumpLabel = 'سانز 🚫';
        trumpColor = const Color(0xFF38BDF8);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHudItem(
                label: 'الجولة',
                value: '${ctx.roundNumber} / ${ctx.totalRounds}',
                color: AppTheme.goldLight,
              ),
              _buildHudItem(
                label: 'القطوع (Trump)',
                value: trumpLabel,
                color: trumpColor,
              ),
              _buildHudItem(
                label: 'موقعك',
                value: ctx.playerPosition,
                color: AppTheme.cream,
              ),
            ],
          ),
          if (ctx.highBidInfo != null ||
              ctx.scoreSituation != null ||
              ctx.declaredCallsInfo != null ||
              ctx.currentTricksWon != null) ...[
            const Divider(color: Colors.white12, height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (ctx.highBidInfo != null)
                  _buildHudTag(AppIcons.gavel, ctx.highBidInfo!, const Color(0xFFF59E0B)),
                if (ctx.declaredCallsInfo != null)
                  _buildHudTag(AppIcons.formatListNumbered, ctx.declaredCallsInfo!, const Color(0xFF10B981)),
                if (ctx.currentTricksWon != null)
                  _buildHudTag(AppIcons.stars, 'أكلاتك المحققة: ${ctx.currentTricksWon}', const Color(0xFF8B5CF6)),
                if (ctx.scoreSituation != null)
                  _buildHudTag(AppIcons.barChart, ctx.scoreSituation!, const Color(0xFF38BDF8)),
              ],
            ),
          ],
          if (ctx.currentTrickCards != null && ctx.currentTrickCards!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'الورق الملعوب على الأرض في هذه اللمة:',
              style: GoogleFonts.cairo(color: AppTheme.steelBlue, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Row(
              children: ctx.currentTrickCards!.map((tc) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    children: [
                      PlayingCardWidget(card: tc.card, width: 44, playable: false),
                      const SizedBox(height: 2),
                      Text(
                        tc.playerId,
                        style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHudItem({required String label, required String value, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(color: AppTheme.steelBlue, fontSize: 10.5),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(color: color, fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHudTag(AppIconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Player Hand Viewer ─────────────────────────────────────────────────────

  Widget _buildHandViewer(List<PlayingCard> hand, bool isPortrait) {
    final cardWidth = isPortrait ? 48.0 : 58.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'يدك الحالية (${hand.length} ورقة):',
                style: GoogleFonts.cairo(
                  color: AppTheme.cream,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'اسحب لرؤية باقي الأوراق ←',
                  style: GoogleFonts.cairo(color: Colors.white54, fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < hand.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: PlayingCardWidget(
                      card: hand[i],
                      width: cardWidth,
                      playable: false,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Prompt Card ────────────────────────────────────────────────────────────

  Widget _buildPromptCard(EstimationPuzzle puzzle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: puzzle.category.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(AppIcons.helpOutline, color: puzzle.category.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      puzzle.scenarioText,
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      puzzle.prompt,
                      style: GoogleFonts.cairo(
                        color: AppTheme.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Options List ───────────────────────────────────────────────────────────

  Widget _buildOptionsList(EstimationPuzzle puzzle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: puzzle.options.map((option) {
        final isSelected = _selectedOptionId == option.id;

        Color borderColor = Colors.white12;
        Color bgColor = Colors.white.withValues(alpha: 0.04);

        if (_isSubmitted) {
          if (option.isOptimal) {
            borderColor = const Color(0xFF10B981);
            bgColor = const Color(0xFF10B981).withValues(alpha: 0.2);
          } else if (isSelected && !option.isOptimal) {
            borderColor = option.quality.color;
            bgColor = option.quality.color.withValues(alpha: 0.2);
          }
        } else if (isSelected) {
          borderColor = AppTheme.gold;
          bgColor = AppTheme.gold.withValues(alpha: 0.15);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: _isSubmitted ? null : () => _onSelectOption(option),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: isSelected || (_isSubmitted && option.isOptimal) ? 1.6 : 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppTheme.gold : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppTheme.gold : Colors.white38,
                        width: 1.4,
                      ),
                    ),
                    child: isSelected
                        ? const AppIcon(AppIcons.checkRounded, color: AppTheme.navyDark, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  if (option.cardToPlay != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: PlayingCardWidget(card: option.cardToPlay, width: 34, playable: false),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      option.label,
                      style: GoogleFonts.cairo(
                        color: isSelected ? AppTheme.white : Colors.white70,
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

  // ── Submit Button ──────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    final isEnabled = _selectedOptionId != null && !_isEvaluating;

    return ElevatedButton(
      onPressed: isEnabled ? _onSubmit : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.gold,
        disabledBackgroundColor: Colors.white12,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _isEvaluating
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: AppTheme.navyDark, strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(AppIcons.checkCircleOutline, color: AppTheme.navyDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  'تأكيد الإجابة',
                  style: GoogleFonts.cairo(
                    color: AppTheme.navyDark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }

  // ── Feedback Card ──────────────────────────────────────────────────────────

  Widget _buildFeedbackCard(EstimationPuzzle puzzle) {
    final result = _lastResult ?? PuzzleResultQuality.invalid;
    final selectedOption = puzzle.options.firstWhere(
      (o) => o.id == _selectedOptionId,
      orElse: () => puzzle.options.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: result.color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: result.color.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: result.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  result.arabicLabel,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (result.isSuccessful) ...[
                Text(
                  '+${puzzle.xpReward} XP ⚡',
                  style: GoogleFonts.cairo(
                    color: AppTheme.goldLight,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Option Feedback
          Text(
            selectedOption.feedback,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),

          const Divider(color: Colors.white24, height: 20),

          // Tactical Rationale
          Text(
            '🧠 التحليل التكتيكي الشامل:',
            style: GoogleFonts.cairo(
              color: AppTheme.goldLight,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            puzzle.tacticalRationale,
            style: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              if (!result.isSuccessful) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.gold,
                      side: const BorderSide(color: AppTheme.gold),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'إعادة المحاولة 🔄',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _onNextPuzzle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.navyDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    result.isSuccessful ? 'اللغز التالي ⏭️' : 'العودة للقائمة',
                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
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
