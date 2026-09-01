// lib/widgets/declaration_dialog.dart
//
// Post-auction declaration dialog for non-Bidder & Bidder players.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/models/game_state.dart';
import '../core/models/player.dart';
import '../core/widgets/player_avatar.dart';
import '../core/events/estimation_event_dispatcher.dart';
import '../theme/app_theme.dart';
import 'hud/gameplay_dialog_shell.dart';
import 'hud/turn_timer_badge.dart';

class DeclarationDialog extends StatefulWidget {
  final void Function(int declared) onSubmit;
  final int? forbiddenDeclaration;
  final int? minDeclaration;
  final int? maxDeclaration;
  final GameState? state;
  final Player? me;

  const DeclarationDialog({
    super.key, 
    required this.onSubmit, 
    this.forbiddenDeclaration,
    this.minDeclaration,
    this.maxDeclaration,
    this.state,
    this.me,
  });

  @override
  State<DeclarationDialog> createState() => _DeclarationDialogState();
}

class _DeclarationDialogState extends State<DeclarationDialog> {
  // ValueNotifier — selection state inside the dialog; no setState needed.
  late final _declared = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    int maxAllowed = widget.maxDeclaration ?? 13;
    int initial = (widget.minDeclaration ?? 0).clamp(0, maxAllowed);
    if (initial == widget.forbiddenDeclaration) {
      if (initial < maxAllowed) {
        initial++;
      } else if (initial > (widget.minDeclaration ?? 0)) {
        initial--;
      }
    }
    _declared.value = initial;
  }

  @override
  void dispose() {
    _declared.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final me = widget.me;

    int totalDeclaredSoFar = 0;
    Player? rightPlayer;
    Player? topPlayer;
    Player? leftPlayer;

    if (state != null && me != null) {
      totalDeclaredSoFar = state.players
          .where((p) => p.declared != null)
          .fold<int>(0, (sum, p) => sum + p.declared!);

      final mySeat = me.seatIndex;
      rightPlayer = state.playerBySeat((mySeat + 1) % 4);
      topPlayer = state.playerBySeat((mySeat + 2) % 4);
      leftPlayer = state.playerBySeat((mySeat + 3) % 4);
    }

    return GameplayDialogShell(
      maxWidth: GameplayDialogShell.widthFor(context),
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'كم لمة تتوقع؟',
                style: GoogleFonts.cairo(
                  color: AppTheme.cream,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TurnTimerBadge(
                customPhaseLabel: 'DECLARATION',
                isMyTurn: true,
                compact: true,
                explicitDurationSeconds: state?.turnDurationSeconds ?? 15,
                explicitDeadlineEpochMs: state?.turnDeadlineEpochMs,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'حدد عدد اللمات التي ستربحها هذه الجولة',
              style: GoogleFonts.cairo(
                color: AppTheme.steelBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
              if (state != null) _buildCompactBidderBanner(state, me),
              if (state?.isDoubleRound == true) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF9100).withValues(alpha: 0.25),
                        const Color(0xFFFFD700).withValues(alpha: 0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('⚡', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        '⚡ ×2 ROUND (جولة مضاعفة النقاط)',
                        style: TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Other Players Info Cards (Left, Top, Right) ──
              if (leftPlayer != null && topPlayer != null && rightPlayer != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPlayerCard(leftPlayer, 'يسار', '👈', state!),
                    const SizedBox(width: 6),
                    _buildPlayerCard(topPlayer, 'أعلى', '👆', state),
                    const SizedBox(width: 6),
                    _buildPlayerCard(rightPlayer, 'يمين', '👉', state),
                  ],
                ),
                const SizedBox(height: 8),
                // Total declared chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.navyMid,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '📊 إجمالي اللمات المصرحة حتى الآن: $totalDeclaredSoFar / 13',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              
              // Restrictions / Warnings
              if (widget.minDeclaration != null) ...[
                const SizedBox(height: 6),
                Text(
                  '👑 لأنك صاحب المزاد، يجب أن تتوقع ${widget.minDeclaration} لمات أو أكثر',
                  style: const TextStyle(
                      color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              if (widget.maxDeclaration != null && widget.maxDeclaration! < 13) ...[
                const SizedBox(height: 6),
                Text(
                  '📌 لا يمكنك طلب أكلات أكثر من صاحب المزاد (${widget.maxDeclaration})',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
              if (widget.forbiddenDeclaration != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '⚠️ الرقم ${widget.forbiddenDeclaration} ممنوع (لتفادي مجموع = 13)!',
                    style: const TextStyle(
                        color: AppTheme.errorRed, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Number grid 0–13
              ValueListenableBuilder<int>(
                valueListenable: _declared,
                builder: (context, declared, _) {
                  final isWith = state?.bidder?.declared != null &&
                      declared == state?.bidder?.declared &&
                      me?.id != state?.bidderPlayerId;
                  final isRisk = widget.forbiddenDeclaration != null &&
                      (totalDeclaredSoFar + declared <= 11);

                  return Column(
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          for (int i = 0; i <= 13; i++)
                            Builder(builder: (context) {
                              final isForbidden = i == widget.forbiddenDeclaration;
                              final isBelowMin =
                                  widget.minDeclaration != null && i < widget.minDeclaration!;
                              final isAboveMax =
                                  widget.maxDeclaration != null && i > widget.maxDeclaration!;
                              final isDisabled = isForbidden || isBelowMin || isAboveMax;
                              final isSelected = declared == i;
                              return GestureDetector(
                                onTap: isForbidden
                                    ? () {
                                        if (widget.me != null) {
                                          EstimationEventDispatcher.instance
                                              .notifyForbiddenDeclarationAttempt(
                                                  widget.me!, i);
                                        }
                                      }
                                    : (isDisabled ? null : () => _declared.value = i),
                                child: Opacity(
                                  opacity: isDisabled ? 0.25 : 1.0,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.gold : AppTheme.surfaceCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.gold : Colors.white12,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.gold.withValues(alpha: 0.4),
                                                blurRadius: 10,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$i',
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.navyDark : AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                      ),
                      if (isWith || isRisk) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isWith)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
                                ),
                                child: const Text(
                                  '👑 ويز (With) +10 بونص',
                                  style: TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            if (isRisk)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: const Text(
                                  '⚡ ريسك (Risk) +10 بونص',
                                  style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.navyDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onSubmit(declared);
                          },
                          child: Text(
                            'تأكيد: $declared لمة',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(
      Player player, String positionLabel, String positionIcon, GameState state) {
    final hasDeclared = player.declared != null;
    final isBidder = state.currentHighBidderPlayerId == player.id;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: hasDeclared
              ? AppTheme.navyMid
              : AppTheme.navyDark.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasDeclared
                ? AppTheme.gold.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
            width: hasDeclared ? 1.5 : 1.0,
          ),
          boxShadow: hasDeclared
              ? [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Position Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(positionIcon, style: const TextStyle(fontSize: 10)),
                  const SizedBox(width: 2),
                  Text(
                    positionLabel,
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Avatar
            if (player.photo != null)
              PlayerAvatar(
                photoData: player.photo!,
                size: 28,
                borderColor: hasDeclared ? AppTheme.gold : Colors.white30,
                borderWidth: 1.5,
                hasBorder: true,
              )
            else
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.navyDark,
                  border: Border.all(
                    color: hasDeclared ? AppTheme.gold : Colors.white30,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 4),

            // Name + Bidder icon
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isBidder) ...[
                  const Text('👑', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    player.name,
                    style: TextStyle(
                      color: isBidder ? AppTheme.gold : AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            // Bidder tricks count & trump beside/under name
            if (isBidder && (state.trump != null || state.currentHighBid != null)) ...[
              const SizedBox(height: 2),
              Builder(
                builder: (context) {
                  final trump = state.trump ?? state.currentHighBid?.trump;
                  final trickCount = state.currentHighBid?.trickCount;
                  final trumpColor = _getTrumpColor(trump);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.navyDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: trumpColor.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (trickCount != null) ...[
                          Text(
                            '$trickCount',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                        if (trump != null) ...[
                          Text(
                            trump.isSans ? 'NT' : trump.label,
                            style: TextStyle(
                              color: trumpColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            trump.arabicName,
                            style: TextStyle(
                              color: trumpColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 6),

            // Declaration Box
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: hasDeclared
                    ? AppTheme.gold
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasDeclared
                      ? AppTheme.gold
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hasDeclared ? '✅ ${player.declared} لمات' : '⏳ لم يصرح',
                  style: TextStyle(
                    color: hasDeclared ? AppTheme.navyDark : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: hasDeclared ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBidderBanner(GameState state, Player? me) {
    final bidder = state.bidder;
    final winningBid = state.currentHighBid;
    final trump = state.trump ?? winningBid?.trump;
    if (bidder == null && trump == null) return const SizedBox.shrink();

    final isMeBidder = bidder != null && bidder.id == me?.id;
    final bidderName = isMeBidder ? 'أنت' : (bidder?.name ?? 'غير محدد');
    final trickCount = winningBid?.trickCount ?? bidder?.declared;
    final trumpColor = _getTrumpColor(trump);

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.navyMid.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👑', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          const Text(
            'صاحب المزاد: ',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              bidderName,
              style: TextStyle(
                color: isMeBidder ? AppTheme.playerGreen : AppTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.navyDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: trumpColor.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trickCount != null) ...[
                  Text(
                    '$trickCount',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (trump != null) ...[
                  Text(
                    trump.isSans ? 'NT' : trump.label,
                    style: TextStyle(
                      color: trumpColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    trump.arabicName,
                    style: TextStyle(
                      color: trumpColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

  Color _getTrumpColor(Trump? trump) {
    if (trump == null) return AppTheme.gold;
    switch (trump) {
      case Trump.heart:
      case Trump.diamond:
        return const Color(0xFFFF5252);
      case Trump.spade:
      case Trump.club:
        return const Color(0xFFE2E8F0);
      case Trump.sans:
        return AppTheme.gold;
    }
  }
}

