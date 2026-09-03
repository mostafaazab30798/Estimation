// lib/widgets/online_play_gate_lifecycle.dart
//
// Pauses [OnlinePlayGate] background polling while an online match is active.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/online_play_gate.dart';

/// Wraps online play surfaces (matchmaking, lobby, game) so gate polling
/// does not hammer SharedPreferences / Supabase during a live match.
class OnlinePlayGateMatchScope extends StatefulWidget {
  const OnlinePlayGateMatchScope({super.key, required this.child});

  final Widget child;

  @override
  State<OnlinePlayGateMatchScope> createState() =>
      _OnlinePlayGateMatchScopeState();
}

class _OnlinePlayGateMatchScopeState extends State<OnlinePlayGateMatchScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OnlinePlayGate>().suppressWhileInMatch();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
