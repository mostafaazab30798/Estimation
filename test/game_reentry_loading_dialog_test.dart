import 'dart:async';

import 'package:estimation/widgets/game_reentry_loading_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading UI until game recovery completes', (tester) async {
    final recovery = Completer<String>();
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await runWithGameReentryLoading(
                context,
                operation: () => recovery.future,
              );
            },
            child: const Text('Re-enter'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Re-enter'));
    await tester.pump();

    expect(find.text('جاري العودة إلى المباراة'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    recovery.complete('restored');
    await tester.pumpAndSettle();

    expect(find.text('جاري العودة إلى المباراة'), findsNothing);
    expect(result, 'restored');
  });
}
