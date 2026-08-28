import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/game_state.dart';
import '../../../../providers/game_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/models/matchmaking_status.dart';
import '../widgets/bot_fill_dialog.dart';
import '../widgets/matchmaking_player_slot.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  bool _dialogOpen = false;
  bool _hasNavigatedToGame = false;
  bool _leaving = false;
  int? _dialogVersion;

  Future<void> _cancel() async {
    if (_leaving) return;
    _leaving = true;
    await context.read<GameProvider>().cancelMatchmaking();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/kotchina/home', (_) => false);
    }
  }

  void _reactToState(GameProvider provider) {
    final room = provider.currentRoom;
    final shouldVote = room?.isBotVoteOpen == true &&
        provider.matchmakingHumanCount >= 2 &&
        provider.matchmakingHumanCount <= 3;
    if (_dialogOpen &&
        (!shouldVote || room!.botOfferVersion != _dialogVersion)) {
      _dialogOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      });
    }
    if (shouldVote &&
        !_dialogOpen &&
        provider.claimBotOfferPresentation(room!.botOfferVersion)) {
      _dialogOpen = true;
      _dialogVersion = room.botOfferVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted ||
            provider.currentRoom?.botOfferVersion != _dialogVersion) {
          return;
        }
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => BotFillDialog(
            humanCount: provider.matchmakingHumanCount,
            onVote: (accepted) async {
              await provider.voteForBotFill(
                  offerVersion: _dialogVersion!, accepted: accepted);
              if (mounted && _dialogOpen) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
          ),
        );
        _dialogOpen = false;
      });
    }
    if (!_hasNavigatedToGame &&
        provider.state?.phase != null &&
        provider.state!.phase != GamePhase.lobby) {
      _hasNavigatedToGame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, '/game');
      });
    }
  }

  String _status(GameProvider provider) {
    if (provider.matchmakingStatus == MatchmakingStatus.starting ||
        provider.matchmakingStatus == MatchmakingStatus.playing) {
      return 'اكتملت الطاولة! جاري بدء المباراة...';
    }
    if (provider.currentRoom?.isBotVoteOpen == true &&
        provider.currentRoom!.botYesVotes > 0) {
      return 'في انتظار موافقة باقي اللاعبين...';
    }
    return switch (provider.matchmakingHumanCount) {
      1 => 'جاري البحث عن لاعبين...',
      2 => 'تم العثور على لاعب آخر — نبحث عن لاعبين إضافيين',
      3 => 'باقي لاعب واحد فقط',
      _ => 'اكتمل الفريق — جاري بدء المباراة...',
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    _reactToState(provider);
    final starting = provider.matchmakingStatus == MatchmakingStatus.starting ||
        provider.matchmakingStatus == MatchmakingStatus.playing;
    final players = provider.roomPlayers;
    final bots = starting ? provider.matchmakingBotsToFill : 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !starting) _cancel();
      },
      child: Scaffold(
        backgroundColor: AppTheme.navyDark,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('جاري البحث عن لاعبين',
                          style: GoogleFonts.cairo(
                              color: AppTheme.gold,
                              fontSize: 26,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text('${provider.matchmakingHumanCount} / 4',
                          style: GoogleFonts.cairo(
                              color: AppTheme.cream, fontSize: 20)),
                      const SizedBox(height: 24),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.55),
                        itemCount: 4,
                        itemBuilder: (_, index) {
                          if (index < players.length) {
                            return MatchmakingPlayerSlot(
                                playerName: players[index].playerName);
                          }
                          if (index < players.length + bots) {
                            return const MatchmakingPlayerSlot(isBot: true);
                          }
                          return const MatchmakingPlayerSlot();
                        },
                      ),
                      const SizedBox(height: 24),
                      if (!starting)
                        const CircularProgressIndicator(color: AppTheme.gold),
                      const SizedBox(height: 14),
                      Text(_status(provider),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                              color: AppTheme.cream, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text('يمكنك الإلغاء في أي وقت قبل بدء المباراة',
                          style: GoogleFonts.cairo(
                              color: AppTheme.steelBlue, fontSize: 12)),
                      const SizedBox(height: 22),
                      OutlinedButton(
                        onPressed: starting || _leaving ? null : _cancel,
                        child: Text(
                            _leaving ? 'جاري الإلغاء...' : 'إلغاء البحث',
                            style: GoogleFonts.cairo()),
                      ),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
