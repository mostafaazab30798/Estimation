// lib/widgets/update_check_tile.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_checker_service.dart';
import '../core/utils/snackbar_helper.dart';
import '../theme/app_theme.dart';
import 'performance_blur.dart';

class UpdateCheckTile extends StatefulWidget {
  const UpdateCheckTile({super.key});

  @override
  State<UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<UpdateCheckTile> {
  bool _isChecking = false;

  // ── Check for update ──────────────────────────────────────────
  Future<void> _checkForUpdate() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final info = await UpdateCheckerService().checkForUpdate();
      if (!mounted) return;

      if (info.updateAvailable) {
        _showUpdateDialog(info);
      } else {
        _showSnackBar(
          'أنت تستخدم أحدث إصدار (${info.currentVersion}) ✓',
          isError: false,
        );
      }
    } catch (e) {
      debugPrint('[UpdateChecker] ERROR: $e');
      if (!mounted) return;
      _showSnackBar('تعذّر التحقق من التحديثات', isError: true);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // ── Update dialog ─────────────────────────────────────────────
  void _showUpdateDialog(UpdateInfo info) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _UpdateDialog(info: info),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    if (isError) {
      SnackbarHelper.showError(context, message);
    } else {
      SnackbarHelper.showSuccess(context, message);
    }
  }

  // ── Tile UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassDecoration(
        borderRadius: 18,
        borderColor: AppTheme.accentBlue.withValues(alpha: 0.25),
        fillColor: AppTheme.navyDark.withValues(alpha: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _checkForUpdate,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: AppTheme.accentBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التحقق من التحديثات',
                        style: GoogleFonts.cairo(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'اضغط للتحقق من توفر إصدار جديد',
                        style: GoogleFonts.cairo(
                          color: AppTheme.accentLight.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppTheme.accentBlue,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.accentLight.withValues(alpha: 0.8),
                        size: 16,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _UpdateDialog — handles the update prompt + download flow
// ════════════════════════════════════════════════════════════════
class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Phase _phase = _Phase.idle;
  double _progress = 0; // 0.0 – 1.0
  String? _errorMessage;
  CancelToken? _cancelToken;

  // ── Open in Browser Fallback ──────────────────────────────────
  Future<void> _openInBrowser() async {
    final urlStr = widget.info.downloadUrl;
    if (urlStr.isEmpty) return;
    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[UpdateChecker] Could not launch URL: $e');
    }
  }

  // ── Start download ────────────────────────────────────────────
  Future<void> _startDownload() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
      _errorMessage = null;
    });

    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('المساحة التخزينية غير متاحة');
      final downloadDir = Directory('${dir.path}/Download');
      await downloadDir.create(recursive: true);
      final savePath = '${downloadDir.path}/update.apk';

      _cancelToken = CancelToken();

      await Dio().download(
        widget.info.downloadUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          if (mounted) {
            setState(() => _progress = received / total);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          followRedirects: true,
        ),
      );

      if (!mounted) return;
      setState(() => _phase = _Phase.installing);

      final result = await OpenFilex.open(savePath);
      debugPrint('[UpdateChecker] OpenFilex result: ${result.message}');

      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (mounted) setState(() => _phase = _Phase.idle);
      } else {
        debugPrint('[UpdateChecker] Download error: $e');
        String msg = 'فشل التحميل، تحقق من اتصالك وحاول مرة أخرى.';
        if (e.response?.statusCode == 404) {
          msg = 'رابط التنزيل غير موجود (404). يرجى التأكد من صحة رابط التنزيل في Supabase.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          msg = 'انتهت مهلة الاتصال أثناء التنزيل. حاول مرة أخرى.';
        }
        if (mounted) {
          setState(() {
            _phase = _Phase.error;
            _errorMessage = msg;
          });
        }
      }
    } catch (e) {
      debugPrint('[UpdateChecker] Install error: $e');
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMessage = 'حدث خطأ أثناء تحميل أو تثبيت التحديث.';
        });
      }
    }
  }

  // ── Cancel download ───────────────────────────────────────────
  void _cancelDownload() {
    _cancelToken?.cancel('user cancelled');
  }

  @override
  void dispose() {
    _cancelToken?.cancel('dialog dismissed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: PerformanceBlur(
        borderRadius: BorderRadius.circular(24),
        sigmaX: 16,
        sigmaY: 16,
        fallbackColor: AppTheme.navyDark.withValues(alpha: 0.96),
        child: Container(
            constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassDecoration(
              borderRadius: 24,
              borderColor: AppTheme.accentBlue.withValues(alpha: 0.35),
              fillColor: AppTheme.navyDark.withValues(alpha: 0.94),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Flexible scrollable body (Header, Version Badges, Release Notes, Status)
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Icon Ring & Title
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.accentBlue, Color(0xFF5B8FE8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentBlue.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.system_update_alt_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'تحديث جديد متاح!',
                                style: GoogleFonts.alexandria(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'يتوفر إصدار جديد من لعبة كوتشينة إستميشن',
                                style: GoogleFonts.cairo(
                                  color: AppTheme.accentLight.withValues(alpha: 0.75),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Version Comparison Badges
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.navyMid.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: _buildVersionPill(
                                  label: 'الإصدار الحالي',
                                  version: widget.info.currentVersion,
                                  color: AppTheme.accentLight,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                color: Colors.white12,
                              ),
                              Expanded(
                                child: _buildVersionPill(
                                  label: 'الإصدار الجديد',
                                  version: widget.info.latestVersion,
                                  color: const Color(0xFF4CAF50),
                                  isHighlight: true,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Release Notes Box
                        if (widget.info.releaseNotes.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.navyDark.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.accentBlue.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppTheme.accentBlue,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ما الجديد في التحديث:',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.mintSoft,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.info.releaseNotes,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.5,
                                    color: AppTheme.accentLight.withValues(alpha: 0.85),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Download Progress State
                        if (_phase == _Phase.downloading || _phase == _Phase.installing) ...[
                          const SizedBox(height: 16),
                          _buildProgressSection(),
                        ],

                        // Error State Box
                        if (_phase == _Phase.error) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.errorRed.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppTheme.errorRed,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage ??
                                        'فشل التحميل، تحقق من اتصالك وحاول مرة أخرى.',
                                    style: GoogleFonts.cairo(
                                      color: AppTheme.errorRed,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Pinned Action Buttons (Always visible at the bottom)
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      );
    }

  Widget _buildVersionPill({
    required String label,
    required String version,
    required Color color,
    bool isHighlight = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: AppTheme.accentLight.withValues(alpha: 0.6),
              fontSize: 10.5,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              version,
              style: GoogleFonts.alexandria(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    final isInstalling = _phase == _Phase.installing;
    final pct = (_progress * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isInstalling ? 'جارٍ التثبيت الآن...' : 'جارٍ تنزيل التحديث...',
              style: GoogleFonts.cairo(
                color: AppTheme.mintSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isInstalling)
              Text(
                '$pct%',
                style: GoogleFonts.alexandria(
                  color: AppTheme.accentBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: isInstalling ? null : _progress,
            minHeight: 8,
            backgroundColor: AppTheme.navyMid,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    switch (_phase) {
      case _Phase.idle:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  foregroundColor: AppTheme.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'لاحقاً',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
            if (widget.info.downloadUrl.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentBlue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _startDownload,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_rounded,
                                color: Colors.white, size: 17),
                            const SizedBox(width: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'تحديث الآن',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );

      case _Phase.downloading:
        return OutlinedButton.icon(
          onPressed: _cancelDownload,
          icon: const Icon(Icons.close_rounded, size: 17),
          label: Text(
            'إلغاء التحميل',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 11),
            foregroundColor: AppTheme.errorRed,
            side: BorderSide(
              color: AppTheme.errorRed.withValues(alpha: 0.4),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );

      case _Phase.installing:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text(
              'يرجى الانتظار حتى يكتمل التثبيت...',
              style: GoogleFonts.cairo(
                color: AppTheme.accentLight.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
        );

      case _Phase.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      foregroundColor: AppTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'إغلاق',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentBlue.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _startDownload,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.refresh_rounded,
                                  color: Colors.white, size: 17),
                              const SizedBox(width: 5),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'إعادة المحاولة',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.info.downloadUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_browser_rounded,
                    size: 18, color: AppTheme.mintSoft),
                label: Text(
                  'فتح رابط التنزيل في المتصفح',
                  style: GoogleFonts.cairo(
                    color: AppTheme.mintSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }
}

enum _Phase { idle, downloading, installing, error }

