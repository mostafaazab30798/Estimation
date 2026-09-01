import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:estimation/services/ugc_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UgcService.instance.resetForTest();
  });

  test('guests can accept community terms locally', () async {
    expect(await UgcService.instance.hasAcceptedCurrentTerms(), isFalse);

    final ok = await UgcService.instance.acceptTerms();

    expect(ok, isTrue);
    expect(await UgcService.instance.hasAcceptedCurrentTerms(), isTrue);
  });

  test('remembered terms skip the community-guidelines prompt', () async {
    SharedPreferences.setMockInitialValues({
      'ugc_terms_version': kCurrentTermsVersion,
    });

    expect(await UgcService.instance.hasAcceptedCurrentTerms(), isTrue);
  });
}
