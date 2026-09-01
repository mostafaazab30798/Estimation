// lib/modes/basra/presentation/widgets/basra_table_area.dart
//
// Center table for Basra: scattered ground cards, Estimation-style play-in,
// then capture grouping into a pile that flies to the winner like a trick.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:estimation/core/models/card.dart';
import 'package:estimation/core/utils/game_layout_metrics.dart';
import 'package:estimation/modes/basra/presentation/providers/basra_game_provider.dart';
import 'package:estimation/services/audio_service.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:estimation/widgets/playing_card_widget.dart';

class _Pose {
  final Offset offset;
  final double rotation;
  const _Pose(this.offset, this.rotation);
}

enum _TableAnim {
  idle,
  playingIn,
  grouping,
  sweeping,
}

class BasraTableArea extends StatefulWidget {
  final BasraGameProvider game;

  const BasraTableArea({super.key, required this.game});

  @override
  State<BasraTableArea> createState() => _BasraTableAreaState();
}

class _BasraTableAreaState extends State<BasraTableArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepCtrl;
  _TableAnim _anim = _TableAnim.idle;
  int _gen = 0;
  String? _handledKey;

  List<PlayingCard> _ground = const [];
  List<PlayingCard> _captured = const [];
  List<PlayingCard> _snapshot = const [];
  PlayingCard? _played;
  int _playRelSeat = 0;
  int _winnerRelSeat = 0;
  bool _playedWasCapture = false;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _ground = List.from(widget.game.tableCards);
    _snapshot = List.from(widget.game.tableCards);
    _handledKey = _turnKey(widget.game.lastTurnResult);
  }

  @override
  void dispose() {
    _gen++;
    _sweepCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BasraTableArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    final turn = widget.game.lastTurnResult;
    final key = _turnKey(turn);
    if (turn != null && key != _handledKey) {
      _handledKey = key;
      _beginTurn(turn);
      return;
    }

    final oldCards = oldWidget.game.tableCards;
    final newCards = widget.game.tableCards;
    if (oldCards.isNotEmpty &&
        newCards.isEmpty &&
        widget.game.phase == BasraPhase.roundFinished &&
        widget.game.lastRoundAwardedFinalTable &&
        _anim == _TableAnim.idle) {
      _beginFinalSweep(oldCards, widget.game.lastCapturePlayerId);
      return;
    }

    if (_anim == _TableAnim.idle) {
      _ground = List.from(newCards);
      _snapshot = List.from(newCards);
    }
  }

  String _turnKey(BasraTurnResult? turn) {
    if (turn == null) return '';
    return '${turn.playerId}-${turn.playedCard.id}-'
        '${turn.tableBefore.map((c) => c.id).join(',')}-'
        '${turn.capturedCards.map((c) => c.id).join(',')}';
  }

  int _relativeSeat(String playerId) {
    return relativeSeatFor(
      widget.game.seatedIndexOf(playerId),
      widget.game.seatedPlayers.length,
    );
  }

  void _beginTurn(BasraTurnResult turn) {
    final gen = ++_gen;
    _sweepCtrl.reset();
    _played = turn.playedCard;
    _captured = List.from(turn.capturedCards);
    _playedWasCapture = turn.wasCapture;
    final endOfRoundSweep = !turn.wasCapture &&
        (widget.game.phase == BasraPhase.roundFinished ||
            widget.game.phase == BasraPhase.finished) &&
        widget.game.lastRoundAwardedFinalTable;
    final sweepWinnerId = turn.wasCapture
        ? turn.playerId
        : (endOfRoundSweep
            ? (widget.game.lastCapturePlayerId ?? turn.playerId)
            : turn.playerId);
    _winnerRelSeat = _relativeSeat(sweepWinnerId);
    _playRelSeat = _relativeSeat(turn.playerId);
    _ground = turn.wasCapture
        ? turn.tableBefore
            .where((c) => !_captured.any((x) => x.id == c.id))
            .toList()
        : List.from(turn.tableBefore);
    _snapshot = turn.wasCapture
        ? List.from(turn.tableBefore)
        : [...turn.tableBefore, turn.playedCard];

    setState(() => _anim = _TableAnim.playingIn);

    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted || gen != _gen) return;
      if (_playedWasCapture) {
        _startGroupAndSweep(gen);
        return;
      }
      if (endOfRoundSweep) {
        _playedWasCapture = true;
        _captured = List.from(turn.tableBefore);
        _ground = const [];
        _startGroupAndSweep(gen);
        return;
      }
      _ground = List.from(widget.game.tableCards);
      _snapshot = List.from(widget.game.tableCards);
      _played = null;
      _captured = const [];
      setState(() => _anim = _TableAnim.idle);
    });
  }

  void _startGroupAndSweep(int gen) {
    setState(() => _anim = _TableAnim.grouping);
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      if (!mounted || gen != _gen) return;
      AudioService.instance.playCollection();
      _sweepCtrl
        ..reset()
        ..forward();
      setState(() => _anim = _TableAnim.sweeping);
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || gen != _gen) return;
        _ground = List.from(widget.game.tableCards);
        _snapshot = List.from(widget.game.tableCards);
        _played = null;
        _captured = const [];
        _sweepCtrl.reset();
        setState(() => _anim = _TableAnim.idle);
      });
    });
  }

  void _beginFinalSweep(List<PlayingCard> leftover, String? winnerId) {
    if (leftover.isEmpty || winnerId == null) return;
    final gen = ++_gen;
    _played = leftover.last;
    _captured = leftover.sublist(0, leftover.length - 1);
    _playedWasCapture = true;
    _winnerRelSeat = _relativeSeat(winnerId);
    _playRelSeat = _winnerRelSeat;
    _ground = const [];
    _startGroupAndSweep(gen);
  }

  static Offset _relSeatToOffset(int relSeat, Size screenSize) {
    const vertFrac = 0.45;
    const horizFrac = 0.45;
    final h = screenSize.height;
    final w = screenSize.width;
    switch (relSeat) {
      case 0:
        return Offset(0, h * vertFrac);
      case 1:
        return Offset(w * horizFrac, 0);
      case 2:
        return Offset(0, -h * vertFrac);
      case 3:
        return Offset(-w * horizFrac, 0);
      default:
        return Offset.zero;
    }
  }

  /// Estimation-style placement: distinct slots with only ±10px / ±12° jitter.
  /// 1–4 cards sit on the N/E/S/W trick seats. More cards use a spaced grid
  /// so faces never stack on top of each other.
  Map<String, _Pose> _posesFor(
    List<PlayingCard> cards,
    double tableW,
    double tableH,
    double cardW,
    double cardH,
  ) {
    final map = <String, _Pose>{};
    if (cards.isEmpty) return map;

    final slots = cards.length <= 4
        ? _plusSlots(tableW, tableH, cardW, cardH)
        : _gridSlots(cards.length, tableW, tableH);

    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      final base = slots[i];
      final rand = math.Random(card.id.hashCode);
      final rot = (rand.nextDouble() * 24 - 12) * math.pi / 180.0;
      final jx = rand.nextDouble() * 20 - 10;
      final jy = rand.nextDouble() * 20 - 10;
      map[card.id] = _Pose(Offset(base.dx + jx, base.dy + jy), rot);
    }
    return map;
  }

  /// Same four seats as Estimation TrickArea: bottom, right, top, left.
  List<Offset> _plusSlots(
    double tableW,
    double tableH,
    double cardW,
    double cardH,
  ) {
    final size = math.min(tableW, tableH);
    final inset = size * 0.02;
    final dy = size / 2 - inset - cardH / 2;
    final dx = size / 2 - inset - cardW / 2;
    return [
      Offset(0, dy),
      Offset(dx, 0),
      Offset(0, -dy),
      Offset(-dx, 0),
    ];
  }

  List<Offset> _gridSlots(int count, double tableW, double tableH) {
    final cols = count <= 6 ? 3 : (count <= 12 ? 4 : 5);
    final rows = (count / cols).ceil();
    final slotW = tableW / cols;
    final slotH = tableH / rows;
    final originX = -((cols - 1) * slotW) / 2;
    final originY = -((rows - 1) * slotH) / 2;
    return [
      for (var i = 0; i < count; i++)
        Offset(
          originX + (i % cols) * slotW,
          originY + (i ~/ cols) * slotH,
        ),
    ];
  }

  double _cardWidthFor(
    int count,
    double tableW,
    double tableH,
    bool portrait,
    GameLayoutMetrics layout,
  ) {
    final n = math.max(count, 1);
    final size = math.min(tableW, tableH);
    if (n <= 4) {
      return layout.basraTableCardWidth(size);
    }
    const jitter = 10.0;
    const gap = 8.0;
    final cols = n <= 6 ? 3 : (n <= 12 ? 4 : 5);
    final rows = (n / cols).ceil();
    final maxFromW = tableW / cols - gap - jitter * 2;
    final maxFromH =
        (tableH / rows - gap - jitter * 2) * playingCardAspectRatio;
    final maxClamp = switch (layout.screenSize) {
      GameScreenSize.phone => 58.0,
      GameScreenSize.tablet => 64.0,
      GameScreenSize.largeTablet => 70.0,
    };
    return math.min(maxFromW, maxFromH).clamp(34.0, maxClamp);
  }

  _Pose _pilePose(PlayingCard card, {required bool isTaker}) {
    if (isTaker) return const _Pose(Offset.zero, 0);
    final rand = math.Random(card.id.hashCode);
    final rot = (rand.nextDouble() * 4 - 2) * math.pi / 180.0;
    final dx = rand.nextDouble() * 6 - 3;
    final dy = rand.nextDouble() * 6 - 3;
    return _Pose(Offset(dx, dy), rot);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final isPortrait =
            MediaQuery.of(context).orientation == Orientation.portrait;
        final layout = GameLayoutMetrics.of(context);
        final poseCards =
            _anim == _TableAnim.idle ? widget.game.tableCards : _snapshot;
        final cardW = _cardWidthFor(poseCards.length, w, h, isPortrait, layout);
        final cardH = cardW / playingCardAspectRatio;
        final groundPoses = _posesFor(poseCards, w, h, cardW, cardH);

        final screenSize = MediaQuery.of(context).size;
        final phase3Target = _relSeatToOffset(_winnerRelSeat, screenSize);

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (_ground.isEmpty &&
                  _captured.isEmpty &&
                  _played == null &&
                  widget.game.tableCards.isEmpty)
                _emptyPlaceholder(cardW, cardH),
              ..._buildGroundCards(
                _anim == _TableAnim.idle ? widget.game.tableCards : _ground,
                groundPoses,
                cardW,
              ),
              if (_anim == _TableAnim.playingIn) ...[
                ..._buildCapturedAtScatter(groundPoses, cardW, glowing: true),
                if (_played != null)
                  _buildPlayInCard(
                    _played!,
                    cardW,
                    target: _playedWasCapture
                        ? const _Pose(Offset.zero, 0)
                        : (groundPoses[_played!.id] ??
                            const _Pose(Offset.zero, 0)),
                  ),
              ],
              if (_anim == _TableAnim.grouping) ...[
                if (_played != null)
                  _posedCard(
                    _played!,
                    cardW,
                    const _Pose(Offset.zero, 0),
                    highlight: true,
                    taker: true,
                  ),
                ..._buildGroupingCards(groundPoses, cardW),
              ],
              if (_anim == _TableAnim.sweeping)
                AnimatedBuilder(
                  animation: _sweepCtrl,
                  builder: (ctx, child) {
                    final curve = CurvedAnimation(
                      parent: _sweepCtrl,
                      curve: Curves.easeOutCubic,
                    );
                    final t = curve.value;
                    final dx = phase3Target.dx * t;
                    final dy = phase3Target.dy * t;
                    final rotation = t * 10 * math.pi / 180.0;
                    final scale = 1.0 - 0.15 * t;
                    final opacity = t >= 0.80
                        ? (1.0 - (t - 0.80) / 0.20).clamp(0.0, 1.0)
                        : 1.0;
                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.rotate(
                          angle: rotation,
                          child: Transform.scale(scale: scale, child: child),
                        ),
                      ),
                    );
                  },
                  child: _buildSweepPile(cardW),
                ),
              if (_playedWasCapture &&
                  (_anim == _TableAnim.grouping ||
                      _anim == _TableAnim.sweeping ||
                      _anim == _TableAnim.playingIn) &&
                  _captured.isNotEmpty)
                Positioned(
                  bottom: 0,
                  child: _captureChip(_captured.length + 1),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyPlaceholder(double cardW, double cardH) {
    return Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.4),
        color: Colors.black.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: Text(
        'الأرض',
        style: GoogleFonts.cairo(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildGroundCards(
    List<PlayingCard> cards,
    Map<String, _Pose> poses,
    double cardW,
  ) {
    return [
      for (final card in cards)
        _posedCard(card, cardW, poses[card.id] ?? const _Pose(Offset.zero, 0)),
    ];
  }

  List<Widget> _buildCapturedAtScatter(
    Map<String, _Pose> poses,
    double cardW, {
    required bool glowing,
  }) {
    return [
      for (final card in _captured)
        _posedCard(
          card,
          cardW,
          poses[card.id] ?? const _Pose(Offset.zero, 0),
          highlight: glowing,
        ),
    ];
  }

  List<Widget> _buildGroupingCards(Map<String, _Pose> scatter, double cardW) {
    return [
      for (final card in _captured)
        _groupingCard(
          card,
          cardW,
          begin: scatter[card.id] ?? const _Pose(Offset.zero, 0),
          end: _pilePose(card, isTaker: false),
        ),
    ];
  }

  Widget _buildSweepPile(double cardW) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (final card in _captured)
          _posedCard(card, cardW, _pilePose(card, isTaker: false)),
        if (_played != null)
          _posedCard(
            _played!,
            cardW,
            const _Pose(Offset.zero, 0),
            highlight: true,
            taker: true,
          ),
      ],
    );
  }

  Widget _buildPlayInCard(PlayingCard card, double cardW, {_Pose? target}) {
    final pose = target ?? const _Pose(Offset.zero, 0);
    return TweenAnimationBuilder<double>(
      key: ValueKey('play-in-${card.id}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        double dx = pose.offset.dx;
        double dy = pose.offset.dy;
        final offsetDist = 50.0 * (1 - val);
        switch (_playRelSeat) {
          case 0:
            dy += offsetDist;
            break;
          case 1:
            dx += offsetDist;
            break;
          case 2:
            dy -= offsetDist;
            break;
          case 3:
            dx -= offsetDist;
            break;
        }
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: pose.rotation,
            child: Opacity(opacity: val.clamp(0.35, 1.0), child: child),
          ),
        );
      },
      child: _cardFace(card, cardW, highlight: _playedWasCapture, taker: true),
    );
  }

  Widget _groupingCard(
    PlayingCard card,
    double cardW, {
    required _Pose begin,
    required _Pose end,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('group-${card.id}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      builder: (context, t, child) {
        final offset = Offset.lerp(begin.offset, end.offset, t)!;
        final rot = begin.rotation + (end.rotation - begin.rotation) * t;
        return Transform.translate(
          offset: offset,
          child: Transform.rotate(angle: rot, child: child),
        );
      },
      child: _cardFace(card, cardW, highlight: true),
    );
  }

  Widget _posedCard(
    PlayingCard card,
    double cardW,
    _Pose pose, {
    bool highlight = false,
    bool taker = false,
  }) {
    return Transform.translate(
      offset: pose.offset,
      child: Transform.rotate(
        angle: pose.rotation,
        child: _cardFace(card, cardW, highlight: highlight, taker: taker),
      ),
    );
  }

  Widget _cardFace(
    PlayingCard card,
    double width, {
    bool highlight = false,
    bool taker = false,
  }) {
    Widget face = PlayingCardWidget(card: card, width: width, playable: false);
    if (taker) {
      face = Transform.scale(scale: 1.06, child: face);
    }
    if (!highlight && !taker) return face;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: (taker ? AppTheme.gold : const Color(0xFFFBBF24))
                .withValues(alpha: taker ? 0.75 : 0.45),
            blurRadius: taker ? 18 : 12,
            spreadRadius: taker ? 1.4 : 0.6,
          ),
        ],
      ),
      child: face,
    );
  }

  Widget _captureChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.55)),
      ),
      child: Text(
        'أخذ $count ورقة',
        style: GoogleFonts.cairo(
          color: AppTheme.goldLight,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Maps seated index (local player = 0) to Estimation relative seats:
/// 0 bottom, 1 right, 2 top, 3 left.
int relativeSeatFor(int seatedIndex, int playerCount) {
  if (seatedIndex <= 0) return 0;
  if (playerCount == 2) return 2;
  if (playerCount == 3) return seatedIndex == 1 ? 3 : 1;
  switch (seatedIndex) {
    case 1:
      return 3;
    case 2:
      return 2;
    case 3:
      return 1;
    default:
      return 0;
  }
}
