import 'package:flutter/material.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

class PlayerAvatar extends StatelessWidget {
  final String photoData;
  final double size;
  final bool hasBorder;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

  const PlayerAvatar({
    super.key,
    required this.photoData,
    this.size = 90,
    this.hasBorder = true,
    this.borderColor = AppTheme.gold,
    this.borderWidth = 3,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    if (ProfileService.isBase64Photo(photoData)) {
      final img = ProfileService.parseBase64Image(photoData);
      if (img != null) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: img, fit: BoxFit.cover),
            border: hasBorder ? Border.all(color: borderColor, width: borderWidth) : null,
            boxShadow: boxShadow ?? AppTheme.glowShadow,
          ),
        );
      }
    }

    // Default or preset avatar
    final avatar = ProfileService.presetAvatars.firstWhere(
      (a) => a.id == photoData,
      orElse: () => ProfileService.presetAvatars.first,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: avatar.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: hasBorder ? Border.all(color: borderColor, width: borderWidth) : null,
        boxShadow: boxShadow ?? AppTheme.glowShadow,
      ),
      child: Center(
        child: Text(
          avatar.emoji,
          style: TextStyle(fontSize: size * 0.45),
        ),
      ),
    );
  }
}
