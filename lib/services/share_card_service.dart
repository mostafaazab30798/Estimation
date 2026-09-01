// lib/services/share_card_service.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../models/playstyle_models.dart';
import '../models/estimation_statistics.dart';

class ShareCardService {
  ShareCardService._internal();
  static final ShareCardService instance = ShareCardService._internal();

  /// Formats the standard text summary of the player identity card
  String generateIdentityCaption({
    required String playerName,
    required PlayerPersonalityProfile profile,
    required PlayerIdentityCardConfig config,
    required EstimationStatistics stats,
    required int level,
  }) {
    final displayName =
        playerName.trim().isNotEmpty ? playerName.trim() : kDefaultPlayerName;
    final archetype = profile.primaryArchetype;
    final accuracyStr = stats.declarationAccuracy.toStringAsFixed(1);

    final caption = StringBuffer()
      ..writeln('♠️ بطاقة لاعب إستميشن • Estimation Identity Card ♠️')
      ..writeln('👑 اللاعب: $displayName')
      ..writeln('📜 اللقب: ${config.selectedTitle}')
      ..writeln('🧠 الشخصية التكتيكية: ${archetype.titleAr} ${archetype.emoji}')
      ..writeln('⭐ المستوى: $level • دقة الكول: $accuracyStr%')
      ..writeln(
          '🏆 الانتصارات: ${stats.gamesWon} • كول مثالي: ${stats.perfectEstimates}')
      ..writeln('🔥 أطول سلسلة فوز: ${stats.longestWinningStreak}')
      ..writeln('✨ "${archetype.taglineAr}"')
      ..writeln('#Estimation #سهرة_ورق #إستميشن');

    return caption.toString();
  }

  /// Formats the standard text summary of match victory
  String generateVictoryCaption({
    required String playerName,
    required int finalScore,
    required int perfectEstimates,
    required int comebacks,
    required int bestRoundDelta,
    required String matchRankTitle,
  }) {
    final displayName =
        playerName.trim().isNotEmpty ? playerName.trim() : kDefaultPlayerName;
    final caption = StringBuffer()
      ..writeln('🏆 انتصار جديد في إستميشن! • Estimation Victory 🏆')
      ..writeln('👑 البطل: $displayName ($matchRankTitle)')
      ..writeln('🎯 السكور النهائي: $finalScore نقطة')
      ..writeln('🎯 كول مثالي: $perfectEstimates جولات')
      ..writeln('🔥 ريمونتادا: $comebacks')
      ..writeln('⭐ أفضل جولة: +$bestRoundDelta نقطة')
      ..writeln('حمّل اللعبة وتحداني على الطاولة! ♠️')
      ..writeln('#Estimation #سهرة_ورق #بطل_البولة');

    return caption.toString();
  }

  /// Captures the [RepaintBoundary] identified by [boundaryKey] as a high-resolution PNG image
  /// and opens the native OS photo share sheet.
  Future<bool> shareIdentityCard({
    required GlobalKey boundaryKey,
    required String playerName,
    required PlayerPersonalityProfile profile,
    required PlayerIdentityCardConfig config,
    required EstimationStatistics stats,
    required int level,
  }) async {
    final displayName =
        playerName.trim().isNotEmpty ? playerName.trim() : kDefaultPlayerName;
    final caption = generateIdentityCaption(
      playerName: playerName,
      profile: profile,
      config: config,
      stats: stats,
      level: level,
    );

    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint(
            '[ShareCardService] RenderRepaintBoundary is null or not yet mounted.');
        return false;
      }

      // High-DPI 3.0 pixel ratio for crystal clear, crisp photo output
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint(
            '[ShareCardService] Failed to encode card image to PNG bytes.');
        return false;
      }

      final buffer = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = displayName.replaceAll(RegExp(r'[^\w\s]+'), '_');
      final filePath =
          '${tempDir.path}/estimation_card_${sanitizedName}_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(buffer);

      // Invoke native OS image share sheet
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(file.path,
                mimeType: 'image/png', name: 'my_estimation_card.png')
          ],
          text: caption,
          subject: 'بطاقة لاعب إستميشن — $displayName',
        ),
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint(
          '[ShareCardService] Error during image generation / native share: $e');
      return false;
    }
  }

  /// Shares a match victory result card as image / native share
  Future<bool> shareMatchVictory({
    required String playerName,
    required int finalScore,
    required int perfectEstimates,
    required int comebacks,
    required int bestRoundDelta,
    required String matchRankTitle,
  }) async {
    final displayName =
        playerName.trim().isNotEmpty ? playerName.trim() : kDefaultPlayerName;
    final caption = generateVictoryCaption(
      playerName: playerName,
      finalScore: finalScore,
      perfectEstimates: perfectEstimates,
      comebacks: comebacks,
      bestRoundDelta: bestRoundDelta,
      matchRankTitle: matchRankTitle,
    );

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: caption,
          subject: '🏆 انتصار إستميشن — $displayName',
        ),
      );
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('[ShareCardService] Share victory native error: $e');
      return false;
    }
  }
}
