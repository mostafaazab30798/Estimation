import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';

class BotFillDialog extends StatefulWidget {
  final int humanCount;
  final Future<void> Function(bool accepted) onVote;

  const BotFillDialog(
      {super.key, required this.humanCount, required this.onVote});

  @override
  State<BotFillDialog> createState() => _BotFillDialogState();
}

class _BotFillDialogState extends State<BotFillDialog> {
  bool _submitting = false;

  Future<void> _vote(bool accepted) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await widget.onVote(accepted);
  }

  @override
  Widget build(BuildContext context) {
    final two = widget.humanCount == 2;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppTheme.navyDark,
        title: Text(two ? 'نبدأ الآن؟ 🤖' : 'باقي لاعب واحد 👀',
            style: GoogleFonts.cairo(
                color: AppTheme.gold, fontWeight: FontWeight.bold)),
        content: Text(
          two
              ? 'تم العثور على لاعبين اثنين. يمكنكم مواصلة البحث، أو بدء المباراة وإكمال الطاولة بلاعبين بوت.'
              : 'يمكنكم انتظار لاعب رابع، أو بدء المباراة الآن مع لاعب بوت واحد.',
          style: GoogleFonts.cairo(color: AppTheme.cream, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: _submitting ? null : () => _vote(false),
              child: Text('استمر في البحث', style: GoogleFonts.cairo())),
          FilledButton(
              onPressed: _submitting ? null : () => _vote(true),
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(two ? 'ابدأ مع البوتات' : 'ابدأ مع بوت',
                      style: GoogleFonts.cairo())),
        ],
      ),
    );
  }
}
