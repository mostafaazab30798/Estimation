import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:estimation/services/profile_service.dart';
import 'package:estimation/widgets/player_name_prompt.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('skips the dialog when a valid name is already set', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ensurePlayerName(context, currentName: 'أحمد');
            },
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerNamePromptDialog), findsNothing);
    expect(result, 'أحمد');
  });

  testWidgets('prompts, saves, and returns a new name', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ensurePlayerName(context, currentName: '');
            },
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerNamePromptDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'سامي');
    await tester.tap(find.text('حفظ والدخول'));
    await tester.pumpAndSettle();

    expect(result, 'سامي');
    expect(await ProfileService.getProfileName(), 'سامي');
  });
}
