/// Neutralises spreadsheet formula injection (CSV injection, CWE-1236) in
/// exported files.
///
/// BudgetSense exports are opened in Excel, Numbers, LibreOffice and Google
/// Sheets. Those applications treat any cell whose text begins with `=`, `+`,
/// `-`, `@`, or a leading control character as a *formula* rather than as
/// text. A transaction note the user was tricked into pasting, or a merchant
/// name imported from another app's file, can therefore execute when the
/// export is opened, and formulas can reach out to the network (`WEBSERVICE`,
/// `IMPORTXML`, DDE) to exfiltrate the rest of the sheet.
///
/// The fix is the standard one: prefix an apostrophe, which every mainstream
/// spreadsheet reads as "the rest of this cell is literal text". The apostrophe
/// is not part of the stored value, so nothing in the database changes; only
/// the rendering of the exported cell does.
///
/// Apply this to FREE TEXT the user or an imported file controls. Do not apply
/// it to values BudgetSense generates itself, such as formatted amounts, which
/// legitimately begin with `-` for a negative number and must stay numeric for
/// the spreadsheet to total them.
abstract final class SpreadsheetSafety {
  /// Leading characters that make a spreadsheet parse a cell as a formula.
  ///
  /// The control characters matter because a cell such as "\t=cmd" is trimmed
  /// by the spreadsheet before it decides how to parse the contents, so the
  /// `=` still wins if only the first character is inspected.
  static const Set<String> _dangerousLeadingChars = {
    '=',
    '+',
    '-',
    '@',
    '\t',
    '\r',
    '\n',
  };

  /// Returns [value] rendered so a spreadsheet treats it as text.
  ///
  /// Returns the value unchanged when it cannot be read as a formula, so
  /// ordinary notes and merchant names survive the export byte-for-byte.
  static String cell(String value) {
    if (value.isEmpty) return value;
    return _dangerousLeadingChars.contains(value[0]) ? "'$value" : value;
  }
}
