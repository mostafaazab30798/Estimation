// lib/widgets/hud/reaction_picker_sheet.dart
//
// Redesigned modern reaction picker bottom sheet with categorized tabs:
// Emojis, Tactical card phrases, and Banter / Taunts.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/game_reaction.dart';
import '../../theme/app_theme.dart';
import 'package:estimation/core/icons/app_icons.dart';

class ReactionPickerSheet extends StatefulWidget {
  final void Function(String emoji, [String? text]) onSelectReaction;

  const ReactionPickerSheet({
    super.key,
    required this.onSelectReaction,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(String emoji, [String? text]) onSelectReaction,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ReactionPickerSheet(onSelectReaction: onSelectReaction),
    );
  }

  @override
  State<ReactionPickerSheet> createState() => _ReactionPickerSheetState();
}

class _ReactionPickerSheetState extends State<ReactionPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onPick(String emoji, [String? text]) {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    Navigator.of(context).pop();
    widget.onSelectReaction(emoji, text);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final sheetHeight = isLandscape ? 260.0 : 380.0;

    return Container(
      height: sheetHeight,
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.navyDark.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.2),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Handle & Header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const AppIcon(
                          AppIcons.chatBubbleOutline,
                          color: AppTheme.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تفاعل في اللعبة',
                          style: AppFonts.cooper(
                            color: AppTheme.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.close, color: Colors.white70, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab Bar ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.gold, AppTheme.goldLight],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.navyDark,
              unselectedLabelColor: Colors.white70,
              labelStyle: AppFonts.cooper(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: AppFonts.cooper(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'رموز تعبيرية 🔥'),
                Tab(text: 'عبارات تكتيكية 🎯'),
                Tab(text: 'ضحك وتحفيل 😂'),
              ],
            ),
          ),

          // ── Tab Views ───────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmojisGrid(),
                _buildPhrasesList(GameReaction.tactical),
                _buildPhrasesList(GameReaction.banter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojisGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 10,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: GameReaction.emojis.length,
      itemBuilder: (context, index) {
        final preset = GameReaction.emojis[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _onPick(preset.emoji),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Center(
                child: Text(
                  preset.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhrasesList(List<ReactionPreset> presets) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: presets.map((preset) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _onPick(preset.emoji, preset.text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      preset.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      preset.text ?? '',
                      style: AppFonts.cooper(
                        color: AppTheme.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
