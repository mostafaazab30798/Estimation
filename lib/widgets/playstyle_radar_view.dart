// lib/widgets/playstyle_radar_view.dart

import 'package:flutter/material.dart';
import '../models/playstyle_models.dart';
import '../theme/app_theme.dart';
import 'package:estimation/core/icons/app_icons.dart';

class PlaystyleRadarView extends StatelessWidget {
  final PlaystyleMetrics metrics;
  final bool showConfidenceBadge;

  const PlaystyleRadarView({
    super.key,
    required this.metrics,
    this.showConfidenceBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final dimensions = [
      _DimensionItem(
        titleAr: 'الهجوم والمبادرة',
        value: metrics.aggression,
        icon: AppIcons.localFireDepartment,
        color: const Color(0xFFEF4444),
        description: 'الجرأة في انتزاع المزاد والمزايدة بأعداد لامات مرتفعة',
      ),
      _DimensionItem(
        titleAr: 'الحذر والتحفظ',
        value: metrics.conservatism,
        icon: AppIcons.shield,
        color: const Color(0xFF10B981),
        description: 'تفضيل العقود الآمنة وتفادي عقوبات السالب',
      ),
      _DimensionItem(
        titleAr: 'المجازفة والمخاطرة',
        value: metrics.riskTaking,
        icon: AppIcons.casino,
        color: const Color(0xFFF59E0B),
        description: 'الإقدام على كولات الداش والريسك والكولات الصعبة',
      ),
      _DimensionItem(
        titleAr: 'الدقة والانضباط',
        value: metrics.precision,
        icon: AppIcons.trackChanges,
        color: const Color(0xFF38BDF8),
        description: 'التقارب التام بين اللامات المعلنة والمكاسب الفعلية',
      ),
      _DimensionItem(
        titleAr: 'دقة إعلان الكول',
        value: metrics.declarationAccuracy,
        icon: AppIcons.gpsFixed,
        color: const Color(0xFF8B5CF6),
        description: 'نسبة مطابقة الكول التام (Perfect Estimates)',
      ),
      _DimensionItem(
        titleAr: 'المرونة والتكيف',
        value: metrics.adaptability,
        icon: AppIcons.cached,
        color: const Color(0xFF06B6D4),
        description: 'التأقلم مع توزيع الورق ومواقف اللعب غير المتوقعة',
      ),
      _DimensionItem(
        titleAr: 'الثقة في كول القطوع',
        value: metrics.trumpConfidence,
        icon: AppIcons.star,
        color: const Color(0xFFEC4899),
        description: 'استغلال لون الصنعة وتحقيق أكبر استفادة منه',
      ),
      _DimensionItem(
        titleAr: 'الريمونتادا والعودة',
        value: metrics.comebackAbility,
        icon: AppIcons.replayCircleFilled,
        color: const Color(0xFFA855F7),
        description: 'القدرة على تعويض الفارق النقطي عند التأخر',
      ),
      _DimensionItem(
        titleAr: 'انضباط المزايدة',
        value: metrics.bidDiscipline,
        icon: AppIcons.balance,
        color: const Color(0xFF14B8A6),
        description: 'تجنب المزايدات المفرطة (Overbidding) والخاسرة',
      ),
      _DimensionItem(
        titleAr: 'الوعي بالسكور',
        value: metrics.scoreAwareness,
        icon: AppIcons.insights,
        color: AppTheme.gold,
        description: 'إدارة النقاط بكفاءة وحماية التقدم نحو الفوز',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showConfidenceBadge) ...[
          _buildConfidenceHeader(),
          const SizedBox(height: 16),
        ],
        ...dimensions.map((dim) => _buildDimensionBar(dim)),
      ],
    );
  }

  Widget _buildConfidenceHeader() {
    final conf = metrics.profileConfidence;
    final label = metrics.confidenceLabelAr;

    Color badgeColor = const Color(0xFFF59E0B);
    if (conf >= 90) {
      badgeColor = const Color(0xFF10B981);
    } else if (conf >= 75) {
      badgeColor = const Color(0xFF38BDF8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.verified, color: badgeColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'موثوقية الملف التكتيكي: ${conf.toStringAsFixed(0)}%',
                  style: AppFonts.cooper(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'مبني على تحليل ${metrics.roundsAnalyzed} جولة لعب فعلية • $label',
                  style: AppFonts.cooper(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: AppFonts.cooper(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.navyDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionBar(_DimensionItem item) {
    final pct = (item.value / 100.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(item.icon, size: 16, color: item.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.titleAr,
                    style: AppFonts.cooper(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cream,
                    ),
                  ),
                ),
                Text(
                  '${item.value.toStringAsFixed(0)}/100',
                  style: AppFonts.cooper(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: item.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              item.color.withValues(alpha: 0.7),
                              item.color,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.description,
              style: AppFonts.cooper(
                fontSize: 10,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionItem {
  final String titleAr;
  final double value;
  final AppIconData icon;
  final Color color;
  final String description;

  const _DimensionItem({
    required this.titleAr,
    required this.value,
    required this.icon,
    required this.color,
    required this.description,
  });
}
