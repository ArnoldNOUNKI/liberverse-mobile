import 'package:flutter_test/flutter_test.dart';
import 'package:liberverse/core/i18n.dart';
import 'package:liberverse/screens/discover.dart' show kmToPos, posToKm;

void main() {
  test('curseur de distance : échelle progressive', () {
    expect(posToKm(0), 0);
    expect(posToKm(100), 500);
    expect(posToKm(kmToPos(50)), inInclusiveRange(45, 55));
  });
  test('traduction : le français reste tel quel', () {
    I18n.I.lang = 'fr';
    expect(tr('Rencontres'), 'Rencontres');
  });
}
