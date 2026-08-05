/// The update manifest hosted as `latest.json` on GitHub Releases.
///
/// Example:
/// ```json
/// {
///   "versionCode": 3,
///   "versionName": "0.2.0",
///   "apkUrl": "https://github.com/owner/repo/releases/latest/download/BudgetSense-release.apk",
///   "sha256": "1bb1dc0160397bc430810be27486b18500c8ffe17598b43acb7fe21c3b144aa6",
///   "notes": "Faster dashboard and a couple of fixes.",
///   "mandatory": false
/// }
/// ```
class UpdateManifest {
  const UpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    this.notes = '',
    this.mandatory = false,
  });

  /// Monotonic integer used for comparison (mirrors Android versionCode).
  final int versionCode;

  /// Human-readable version, shown to the user (e.g. "0.2.0").
  final String versionName;

  /// Direct download URL of the signed APK.
  final String apkUrl;

  /// Expected lowercase hex SHA-256 of the APK bytes. Verified before install.
  final String sha256;

  /// Short, friendly "what's new" note.
  final String notes;

  /// Advisory only. Even when true we never force; we may nudge more clearly.
  final bool mandatory;

  /// Parse and VALIDATE. Throws [FormatException] on anything malformed so a
  /// broken manifest can never drive a download/install.
  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final versionCode = _int(json['versionCode'], 'versionCode');
    final versionName = _str(json['versionName'], 'versionName');
    final apkUrl = _str(json['apkUrl'], 'apkUrl');
    final sha256 = _str(json['sha256'], 'sha256').toLowerCase();

    if (versionCode <= 0) {
      throw const FormatException('versionCode must be a positive integer');
    }
    if (!apkUrl.startsWith('https://')) {
      throw const FormatException('apkUrl must be an https URL');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const FormatException('sha256 must be 64 lowercase hex characters');
    }
    return UpdateManifest(
      versionCode: versionCode,
      versionName: versionName,
      apkUrl: apkUrl,
      sha256: sha256,
      notes: (json['notes'] as String?)?.trim() ?? '',
      mandatory: json['mandatory'] == true,
    );
  }

  /// True when this manifest describes a build newer than [currentVersionCode].
  bool isNewerThan(int currentVersionCode) => versionCode > currentVersionCode;

  static int _int(Object? v, String field) {
    if (v is int) return v;
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
    }
    throw FormatException('$field must be an integer');
  }

  static String _str(Object? v, String field) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    throw FormatException('$field is required');
  }
}
