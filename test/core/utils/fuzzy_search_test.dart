import 'package:budgetsense/core/utils/fuzzy_search.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for the Settings index, using the real labels, sections and
/// keywords so these tests fail if the matcher stops finding actual settings.
class _Item {
  const _Item(this.label, this.section, this.keywords);
  final String label;
  final String section;
  final String keywords;
}

const _index = <_Item>[
  _Item('Theme', 'Appearance',
      'theme dark light amoled glass system appearance mode'),
  _Item(
      'Accent color', 'Appearance', 'accent colour color highlight appearance'),
  _Item('Typeface and font', 'Appearance',
      'font typeface handwriting caveat zen maru text'),
  _Item('Reduce motion', 'Appearance',
      'reduce motion animation accessibility calm'),
  _Item('Haptic feedback', 'Appearance',
      'haptic haptics vibration vibrate feedback touch buzz tactile'),
  _Item('Currency symbol', 'Money and display',
      'currency symbol money rupee dollar euro'),
  _Item(
      'Cloud sync', 'Data', 'cloud sync backup drive google restore encrypted'),
  _Item('Categories', 'Manage', 'category categories color icon bucket manage'),
  _Item('Custom fields', 'Manage', 'custom field fields tag mood note'),
  _Item('Thresholds', 'Manage', 'threshold thresholds limit budget cap alert'),
  _Item('Notifications', 'Manage',
      'notification notifications reminder alert daily'),
  _Item('Trash', 'Data',
      'trash bin deleted removed restore recover archive recycle'),
  _Item('Security and app lock', 'Privacy and security',
      'security lock app lock pin biometric fingerprint face privacy'),
  _Item('Delete all data', 'Privacy and security',
      'delete wipe erase reset clear all data danger'),
];

List<String> _search(String query) => fuzzySearch(
      query,
      _index,
      (i) => [
        SearchableField(i.label, weight: 1),
        SearchableField(i.keywords, weight: 0.8),
        SearchableField(i.section, weight: 0.6),
      ],
    ).map((i) => i.label).toList();

void main() {
  group('normalizeForSearch', () {
    test('folds case and punctuation so spelling variants agree', () {
      expect(normalizeForSearch('Wi-Fi'), 'wi fi');
      expect(normalizeForSearch('  Dark/Light  '), 'dark light');
      expect(normalizeForSearch('1.2k'), '1 2k');
    });
  });

  group('two characters already narrow things down', () {
    test('"th" surfaces Theme and Thresholds', () {
      final hits = _search('th');
      expect(hits, contains('Theme'));
      expect(hits, contains('Thresholds'));
      expect(hits.first, 'Theme', reason: 'exact word prefix should rank top');
    });

    test('"no" finds Notifications', () {
      expect(_search('no'), contains('Notifications'));
    });

    test('"cu" finds Currency symbol and Custom fields', () {
      final hits = _search('cu');
      expect(hits, containsAll(<String>['Currency symbol', 'Custom fields']));
    });
  });

  group('initials', () {
    test('"cs" finds Cloud sync', () {
      expect(_search('cs'), contains('Cloud sync'));
    });

    test('"hf" finds Haptic feedback', () {
      expect(_search('hf'), contains('Haptic feedback'));
    });
  });

  group('every word has to match, so extra words narrow the results', () {
    test('"dark theme" finds Theme', () {
      expect(_search('dark theme'), contains('Theme'));
    });

    test('order of the words does not matter', () {
      expect(_search('theme dark'), _search('dark theme'));
    });

    test('adding an unrelated word removes the result', () {
      expect(_search('theme'), contains('Theme'));
      expect(_search('theme zzzz'), isEmpty);
    });
  });

  group('near misses still land', () {
    test('dropped letters still find the setting', () {
      expect(_search('dkmd'), contains('Theme'));
    });

    test('a mid-word fragment works', () {
      expect(_search('gerprint'), contains('Security and app lock'));
    });

    test('matching on the section name works', () {
      expect(_search('privacy'), contains('Delete all data'));
    });
  });

  group('ranking', () {
    test('an exact label wins over a keyword mention', () {
      expect(_search('trash').first, 'Trash');
    });

    test('a full word beats a loose subsequence', () {
      final hits = _search('lock');
      expect(hits.first, 'Security and app lock');
    });
  });

  group('short queries stay focused', () {
    // Two letters appear in order in almost any sentence, so gapped matching on
    // them used to return most of the index and bury the real hit.
    test('a two-letter query does not drag in most of the index', () {
      for (final q in ['no', 'tr', 'cu', 'th']) {
        expect(_search(q).length, lessThan(_index.length ~/ 2),
            reason: '"$q" returned too many results to be useful');
      }
    });

    test('the intended setting is still first', () {
      expect(_search('no').first, 'Notifications');
      expect(_search('tr').first, 'Trash');
      expect(_search('cu').first, 'Custom fields');
      expect(_search('cs').first, 'Cloud sync');
    });
  });

  group('gapped matches prefer the tighter, word-aligned hit', () {
    test('"bak" finds Cloud sync\'s backup ahead of Haptic feedback', () {
      final hits = _search('bak');
      expect(hits.first, 'Cloud sync');
      expect(hits.indexOf('Cloud sync'),
          lessThan(hits.indexOf('Haptic feedback')));
    });
  });

  group('nothing to match', () {
    test('gibberish returns nothing rather than everything', () {
      expect(_search('qqqzzz'), isEmpty);
    });

    test('an empty or symbol-only query returns nothing', () {
      expect(_search(''), isEmpty);
      expect(_search('   '), isEmpty);
      expect(_search('!!!'), isEmpty);
    });
  });
}
