/// Ranked, forgiving text matching for the small in-memory indexes the app
/// searches (currently the Settings screen).
///
/// The goal is that a couple of characters already narrow things down, the way
/// a web search box does: every word you type has to match something, matches
/// are ranked by how convincing they are, and near-misses like `dk mode` or the
/// initials `cs` still find their setting.
library;

/// One piece of text a result can be matched against, plus how much a hit in it
/// counts. A hit in a visible title should outrank a hit in hidden keywords.
class SearchableField {
  const SearchableField(this.text, {this.weight = 1});

  final String text;
  final double weight;
}

/// Lowercases and reduces anything that is not a letter or digit to a single
/// space, so `Wi-Fi`, `wi fi` and `wifi` all normalise to comparable text.
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  var pendingSpace = false;
  for (final rune in input.toLowerCase().runes) {
    final isDigit = rune >= 0x30 && rune <= 0x39;
    final isLetter = rune >= 0x61 && rune <= 0x7a;
    if (isDigit || isLetter) {
      if (pendingSpace && buffer.isNotEmpty) buffer.write(' ');
      pendingSpace = false;
      buffer.writeCharCode(rune);
    } else {
      pendingSpace = true;
    }
  }
  return buffer.toString();
}

/// Splits a query into the words that must each find a match.
List<String> searchTokens(String query) =>
    normalizeForSearch(query).split(' ').where((t) => t.isNotEmpty).toList();

/// Scores [query] against [fields], or returns null when the query does not
/// match at all.
///
/// Every token has to match somewhere, which is what stops a second word from
/// widening the results instead of narrowing them. A higher score is a better
/// match; the value is only meaningful for sorting.
double? fuzzyScore(String query, List<SearchableField> fields) {
  final tokens = searchTokens(query);
  if (tokens.isEmpty) return null;

  final prepared = [
    for (final field in fields)
      (
        weight: field.weight,
        text: normalizeForSearch(field.text),
        words: normalizeForSearch(field.text).split(' ')
          ..removeWhere((w) => w.isEmpty),
      ),
  ];

  var total = 0.0;
  for (final token in tokens) {
    var best = 0.0;
    for (final field in prepared) {
      final score = _scoreToken(token, field.text, field.words);
      if (score > 0) best = _max(best, score * field.weight);
    }
    if (best == 0) return null;
    total += best;
  }

  // Break ties towards the shorter, more specific entry. Deliberately tiny: it
  // must separate two equally good matches without ever outweighing a genuine
  // difference in match quality.
  final firstFieldLength = prepared.isEmpty ? 0 : prepared.first.text.length;
  return total + 0.01 / (firstFieldLength + 1);
}

/// Below this length a gapped match is not evidence of anything: almost any two
/// letters appear in order somewhere in a sentence, which buries the real hit
/// under most of the index.
const _minLengthForGappedMatch = 3;

double _scoreToken(String token, String text, List<String> words) {
  for (final word in words) {
    if (word == token) return 1;
  }
  for (final word in words) {
    if (word.startsWith(token)) {
      // A prefix covering most of the word is a stronger signal than one or two
      // letters at the start of a long word.
      return 0.7 + 0.15 * (token.length / word.length);
    }
  }
  if (_initials(words).contains(token)) return 0.65;
  if (text.contains(token)) return 0.5;
  if (token.length >= _minLengthForGappedMatch) {
    return _gappedScore(token, text);
  }
  return 0;
}

/// Scores a match whose characters appear in order but not adjacently, so a
/// dropped letter (`bak` for `backup`) still finds its setting.
///
/// Tighter runs score higher, and starting on a word boundary counts for more,
/// which is what separates `bak` in "backup" from the same letters scattered
/// through "feedback".
double _gappedScore(String token, String text) {
  final start = _subsequenceStart(token, text);
  if (start == null) return 0;
  final span = _subsequenceSpan(token, text, start);
  final tightness = token.length / span;
  final onWordBoundary = start == 0 || text[start - 1] == ' ';
  return 0.35 * tightness + (onWordBoundary ? 0.1 : 0);
}

String _initials(List<String> words) {
  final buffer = StringBuffer();
  for (final word in words) {
    if (word.isNotEmpty) buffer.write(word[0]);
  }
  return buffer.toString();
}

/// Index of the earliest character that begins a full in-order match of
/// [token], or null when [text] does not contain one.
int? _subsequenceStart(String token, String text) {
  var index = 0;
  var start = -1;
  for (var i = 0; i < text.length && index < token.length; i++) {
    if (text[i] == token[index]) {
      if (index == 0) start = i;
      index++;
    }
  }
  return index == token.length ? start : null;
}

/// How much of [text] the match spans, starting at [start]. A span equal to the
/// token length means the characters were adjacent.
int _subsequenceSpan(String token, String text, int start) {
  var index = 0;
  for (var i = start; i < text.length; i++) {
    if (text[i] == token[index]) {
      index++;
      if (index == token.length) return i - start + 1;
    }
  }
  return text.length - start;
}

double _max(double a, double b) => a > b ? a : b;

/// Ranks [items] against [query], best match first, dropping non-matches.
///
/// [fieldsOf] describes what each item can be matched on.
List<T> fuzzySearch<T>(
  String query,
  Iterable<T> items,
  List<SearchableField> Function(T item) fieldsOf,
) {
  final scored = <({T item, double score})>[];
  for (final item in items) {
    final score = fuzzyScore(query, fieldsOf(item));
    if (score != null) scored.add((item: item, score: score));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  return [for (final entry in scored) entry.item];
}
