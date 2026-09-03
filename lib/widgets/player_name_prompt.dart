import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/icons/app_icons.dart';
import '../core/utils/display_name_validator.dart';
import '../core/utils/string_utils.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// Returns a valid player name, prompting and saving one if needed.
/// Returns `null` when the user cancels.
Future<String?> ensurePlayerName(
  BuildContext context, {
  String currentName = '',
}) async {
  final existing = currentName.trim();
  if (existing.isNotEmpty && DisplayNameValidator.validate(existing) == null) {
    return StringUtils.capitalizeWords(existing);
  }
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => PlayerNamePromptDialog(initialName: existing),
  );
}

class PlayerNamePromptDialog extends StatefulWidget {
  final String initialName;

  const PlayerNamePromptDialog({super.key, this.initialName = ''});

  @override
  State<PlayerNamePromptDialog> createState() => _PlayerNamePromptDialogState();
}

class _PlayerNamePromptDialogState extends State<PlayerNamePromptDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formatted = StringUtils.capitalizeWords(_controller.text);
    final error = DisplayNameValidator.validate(formatted);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await ProfileService.saveProfileName(formatted);
      try {
        await AuthService.instance.updateProfile(username: formatted);
      } catch (e) {
        debugPrint('[PlayerNamePrompt] profile sync skipped: $e');
      }
      if (!mounted) return;
      Navigator.pop(context, formatted);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'تعذر حفظ الاسم. حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppTheme.steelBlue.withValues(alpha: 0.2)),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: AppTheme.dialogInset,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
          decoration: AppTheme.dialogDecoration(accent: AppTheme.gold),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Center(
                      child: AppIcon(
                        AppIcons.person,
                        color: AppTheme.goldLight,
                        size: 23,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    tooltip: 'إغلاق',
                    icon: const AppIcon(
                      AppIcons.close,
                      color: AppTheme.steelBlue,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'أهلاً بك 👋',
                textAlign: TextAlign.right,
                style: AppFonts.cooper(
                  color: AppTheme.cream,
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اختر الاسم الذي سيراه اللاعبون على الطاولة.',
                textAlign: TextAlign.right,
                style: AppFonts.cooper(
                  color: AppTheme.steelBlue,
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'اسم اللاعب',
                textAlign: TextAlign.right,
                style: AppFonts.cooper(
                  color: AppTheme.cream,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: !_saving,
                autofocus: true,
                textAlign: TextAlign.right,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                maxLength: DisplayNameValidator.maxLength,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) {
                  if (!_saving) _submit();
                },
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    DisplayNameValidator.maxLength,
                  ),
                ],
                style: AppFonts.cooper(
                  color: AppTheme.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'مثال: سامي',
                  hintStyle: AppFonts.cooper(
                    color: AppTheme.steelBlue.withValues(alpha: 0.55),
                    fontSize: 14,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(13),
                    child: AppIcon(
                      AppIcons.person,
                      color: AppTheme.steelBlue,
                      size: 19,
                    ),
                  ),
                  errorText: _error,
                  errorMaxLines: 2,
                  errorStyle: AppFonts.cooper(fontSize: 12, height: 1.3),
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.deepNavy.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: fieldBorder,
                  enabledBorder: fieldBorder,
                  disabledBorder: fieldBorder,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.gold,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.errorRed),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.errorRed,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.deepNavy,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.deepNavy,
                        ),
                      )
                    : Text(
                        'حفظ والدخول',
                        style: AppFonts.cooper(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: AppFonts.cooper(
                    color: AppTheme.steelBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
