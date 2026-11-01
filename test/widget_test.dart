import 'package:flutter_test/flutter_test.dart';
import 'package:healthstats/models/health_models.dart';

void main() {
  test('allure et formatage', () {
    expect(fmtPace(5.5), "5'30\"");
    expect(fmtDuration(const Duration(minutes: 75)), '1h15');
    expect(sportOf(70).strength, true);
  });
}
