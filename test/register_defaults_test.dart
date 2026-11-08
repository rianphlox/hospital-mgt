import 'package:flutter_test/flutter_test.dart';
import 'package:crownlog_flutter/utils/register_defaults.dart';
import 'package:crownlog_flutter/utils/register_import.dart';

void main() {
  test('hospital register defaults', () {
    expect(RegisterDefaults.lga, 'AMAC');
    expect(RegisterDefaults.ward, 'Gwagwa');
    expect(RegisterDefaults.facility, 'The Crown Hospital LTD');
  });

  test('orDefault keeps a written value, fills a blank one', () {
    expect(RegisterDefaults.orDefault(null, 'AMAC'), 'AMAC');
    expect(RegisterDefaults.orDefault('  ', 'AMAC'), 'AMAC');
    expect(RegisterDefaults.orDefault(' Bwari ', 'AMAC'), 'Bwari');
  });

  test('import fills blank LGA / ward / facility, keeps written ones', () {
    const csv =
        'cardNumber,name,lga,ward,facility\n'
        'H 1,Sample One,,,\n'
        'H 2,Sample Two,Bwari,Kubwa,Other Clinic\n';
    final rows = parseRegisterCsv(csv, now: DateTime(2026, 11, 1));
    expect(rows.every((r) => r.isValid), isTrue);
    final blank = rows[0].patient!;
    expect(
      [blank.lga, blank.ward, blank.facility],
      ['AMAC', 'Gwagwa', 'The Crown Hospital LTD'],
    );
    final written = rows[1].patient!;
    expect(
      [written.lga, written.ward, written.facility],
      ['Bwari', 'Kubwa', 'Other Clinic'],
    );
  });

  test('import without those columns uses the defaults', () {
    const csv = 'cardNumber,name\nH 3,Sample Three\n';
    final p = parseRegisterCsv(csv, now: DateTime(2026, 11, 1)).single.patient!;
    expect(
      [p.lga, p.ward, p.facility],
      ['AMAC', 'Gwagwa', 'The Crown Hospital LTD'],
    );
  });
}
