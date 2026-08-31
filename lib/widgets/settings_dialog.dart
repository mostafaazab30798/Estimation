// lib/widgets/settings_dialog.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/earthquake_effect.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import 'package:estimation/core/icons/app_icons.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إعدادات اللعبة',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => const SettingsDialog(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _settings = SettingsService.instance;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.deepNavy.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.gold.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: AnimatedBuilder(
                  animation: _settings,
                  builder: (context, _) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const AppIcon(AppIcons.close, color: AppTheme.steelBlue),
                              splashRadius: 20,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'الإعدادات',
                                  style: GoogleFonts.cairo(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.cream,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const AppIcon(AppIcons.settings, color: AppTheme.gold, size: 22),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppTheme.steelBlue.withValues(alpha: 0.25),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // SFX Toggle
                        _buildSettingTile(
                          icon: _settings.sfxEnabled
                              ? AppIcons.volumeUp
                              : AppIcons.volumeOff,
                          title: 'المؤثرات الصوتية',
                          subtitle: 'أصوات رمي الكروت وسحب اللمات',
                          trailing: Switch(
                            value: _settings.sfxEnabled,
                            activeThumbColor: AppTheme.gold,
                            activeTrackColor: AppTheme.gold.withValues(alpha: 0.4),
                            inactiveThumbColor: AppTheme.steelBlue,
                            inactiveTrackColor: AppTheme.surface2,
                            onChanged: (val) {
                              _settings.setSfxEnabled(val);
                              if (val) AudioService.instance.playCard();
                            },
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Volume Slider
                        if (_settings.sfxEnabled) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Row(
                              children: [
                                AppIcon(
                                  AppIcons.volumeMute,
                                  color: AppTheme.steelBlue.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppTheme.gold,
                                      inactiveTrackColor: AppTheme.surface2,
                                      thumbColor: AppTheme.cream,
                                      overlayColor: AppTheme.gold.withValues(alpha: 0.2),
                                      trackHeight: 4,
                                    ),
                                    child: Slider(
                                      value: _settings.sfxVolume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (val) {
                                        _settings.setSfxVolume(val);
                                      },
                                      onChangeEnd: (val) {
                                        AudioService.instance.playCard();
                                      },
                                    ),
                                  ),
                                ),
                                const AppIcon(
                                  AppIcons.volumeUp,
                                  color: AppTheme.gold,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Haptics Toggle
                        _buildSettingTile(
                          icon: AppIcons.vibration,
                          title: 'الاهتزازات التفاعلية',
                          subtitle: 'اهتزاز عند لعب كارت أو الفوز بالجولة',
                          trailing: Switch(
                            value: _settings.hapticsEnabled,
                            activeThumbColor: AppTheme.gold,
                            activeTrackColor: AppTheme.gold.withValues(alpha: 0.4),
                            inactiveThumbColor: AppTheme.steelBlue,
                            inactiveTrackColor: AppTheme.surface2,
                            onChanged: (val) {
                              _settings.setHapticsEnabled(val);
                            },
                          ),
                        ),

                        const SizedBox(height: 14),
                        _buildEarthquakeEffectPicker(),

                        const SizedBox(height: 22),

                        // Done button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surface2,
                              foregroundColor: AppTheme.cream,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: AppTheme.steelBlue.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            child: Text(
                              'تم',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required AppIconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.steelBlue.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          trailing,
          const Spacer(),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cream,
                  ),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppTheme.steelBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.deepNavy,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.2),
              ),
            ),
            child: AppIcon(icon, color: AppTheme.gold, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildEarthquakeEffectPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.steelBlue.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مؤثر ضربة الزلزال',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.cream,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final effect in EarthquakeEffect.values) ...[
                Expanded(child: _buildEffectChoice(effect)),
                if (effect != EarthquakeEffect.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEffectChoice(EarthquakeEffect effect) {
    final selected = _settings.earthquakeEffect == effect;
    final icon = switch (effect) {
      EarthquakeEffect.magma => AppIcons.localFireDepartment,
      EarthquakeEffect.frost => AppIcons.autoAwesome,
      EarthquakeEffect.voidRift => AppIcons.circle,
    };

    return Tooltip(
      message: effect.arabicDescription,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _settings.setEarthquakeEffect(effect),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: effect.primaryColor.withValues(
                alpha: selected ? 0.22 : 0.07,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? effect.primaryColor
                    : AppTheme.steelBlue.withValues(alpha: 0.14),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon, color: effect.primaryColor, size: 22),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    effect.arabicLabel,
                    style: GoogleFonts.cairo(
                      color: selected ? AppTheme.cream : AppTheme.steelBlue,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
