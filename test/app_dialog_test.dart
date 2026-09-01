import 'package:estimation/core/widgets/app_dialog.dart';
import 'package:estimation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppAlertDialog uses the shared modern dialog chrome',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAlertDialog(
            title: Text('Title'),
            content: Text('Body'),
            actions: [TextButton(onPressed: null, child: Text('Done'))],
          ),
        ),
      ),
    );

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final shape = dialog.shape! as RoundedRectangleBorder;

    expect(dialog.backgroundColor, AppTheme.dialogSurface);
    expect(dialog.surfaceTintColor, Colors.transparent);
    expect(dialog.clipBehavior, Clip.antiAlias);
    expect(shape.borderRadius, BorderRadius.circular(AppTheme.dialogRadius));
    expect(dialog.insetPadding, AppTheme.dialogInset);
  });
}
