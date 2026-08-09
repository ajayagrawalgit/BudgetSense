import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/utils/reminder_schedule.dart';

/// Immutable snapshot of all user preferences (Section 18). Persisted as simple
/// key/values; the heavy financial data lives in the SQLite database instead.
class SettingsState {
  const SettingsState({
    this.onboardingComplete = false,
    this.userName = '',
    this.userNickname = '',
    this.userAge,
    this.userPhone = '',
    this.userEmail = '',
    this.cloudSyncEnabled = false,
    this.currencyCode = 'INR',
    this.currencySymbol = '₹',
    this.localeCode,
    this.dateFormat = 'MMM d, y',
    this.financialMonthStartDay = 1,
    this.themeVariant = AppThemeVariant.system,
    this.accent = AccentPreset.clay,
    this.fontChoice = FontChoice.system,
    this.investmentTreatment = InvestmentTreatment.separate,
    this.investmentTreatmentCustomLabel = '',
    this.reduceMotion = false,
    this.hapticsEnabled = true,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.screenSecurityEnabled = true,
    this.notificationsEnabled = false,
    this.paymentRemindersEnabled = true,
    this.thresholdAlertsEnabled = true,
    this.dailyRecordRemindersEnabled = true,
    this.reminderFrequency = ReminderFrequency.daily,
    this.reminderHour = 22,
    this.reminderMinute = 0,
    this.reminderWeekday = DateTime.monday,
    this.reminderDayOfMonth = 1,
    this.numberFormatCompact = false,
  });

  final bool onboardingComplete;

  // ---- User profile (Section: onboarding). Only [userName] is encouraged;
  // everything else is optional and stays on-device unless cloud sync is on.
  final String userName;

  /// What the user likes to be called. When set, it's used everywhere in place
  /// of the first name.
  final String userNickname;

  final int? userAge;
  final String userPhone;
  final String userEmail;

  /// Opt-in to cloud sync of profile + financial data. The backend is not yet
  /// connected (placeholder); this stores the user's preference for when it is.
  final bool cloudSyncEnabled;

  final String currencyCode;
  final String currencySymbol;
  final String? localeCode;
  final String dateFormat;

  /// 1 to 28 (see FinancialCalendar).
  final int financialMonthStartDay;

  final AppThemeVariant themeVariant;
  final AccentPreset accent;
  final FontChoice fontChoice;
  final InvestmentTreatment investmentTreatment;

  /// User-typed label shown when [investmentTreatment] is
  /// [InvestmentTreatment.custom], e.g. "Retirement" or "Wealth building".
  /// Ignored for every other treatment. Empty by default.
  final String investmentTreatmentCustomLabel;

  /// The label to actually show in the UI: the custom text when the user has
  /// set [InvestmentTreatment.custom] and typed something, otherwise the
  /// treatment's generic [InvestmentTreatmentLabel.label]. Every screen that
  /// displays how investments are treated should read this, not the raw enum,
  /// so a custom name shows up everywhere consistently.
  String get investmentTreatmentLabel =>
      investmentTreatment == InvestmentTreatment.custom &&
              investmentTreatmentCustomLabel.trim().isNotEmpty
          ? investmentTreatmentCustomLabel.trim()
          : investmentTreatment.label;

  // Accessibility & security.
  final bool reduceMotion;

  /// Whether subtle haptic feedback fires across the app. On by default; can be
  /// turned off entirely for people who dislike vibration.
  final bool hapticsEnabled;

  final bool appLockEnabled;
  final bool biometricEnabled;

  /// Block screenshots and screen recording (Android FLAG_SECURE). On by
  /// default to protect financial data; the user can turn it off to capture
  /// screenshots or record the app.
  final bool screenSecurityEnabled;

  // Notifications (Section 12).
  final bool notificationsEnabled;
  final bool paymentRemindersEnabled;
  final bool thresholdAlertsEnabled;

  /// The user-configurable "record your expenses" nudge. Enabled by default and
  /// (by default) fires once a day at 10:00 PM. [dailyRecordRemindersEnabled]
  /// is the on/off switch; the fields below describe when it fires.
  final bool dailyRecordRemindersEnabled;
  final ReminderFrequency reminderFrequency;

  /// Wall-clock time the reminder fires (0-23 / 0-59).
  final int reminderHour;
  final int reminderMinute;

  /// 1 (Mon) to 7 (Sun); used only for a weekly schedule.
  final int reminderWeekday;

  /// 1 to 28; used only for a monthly schedule.
  final int reminderDayOfMonth;

  /// Builds the pure [ReminderSchedule] from the persisted fields.
  ReminderSchedule get reminderSchedule => ReminderSchedule(
        frequency: reminderFrequency,
        hour: reminderHour,
        minute: reminderMinute,
        weekday: reminderWeekday,
        dayOfMonth: reminderDayOfMonth,
      );

  // Number format preference.
  final bool numberFormatCompact;

  SettingsState copyWith({
    bool? onboardingComplete,
    String? userName,
    String? userNickname,
    int? userAge,
    bool clearAge = false,
    String? userPhone,
    String? userEmail,
    bool? cloudSyncEnabled,
    String? currencyCode,
    String? currencySymbol,
    String? localeCode,
    String? dateFormat,
    int? financialMonthStartDay,
    AppThemeVariant? themeVariant,
    AccentPreset? accent,
    FontChoice? fontChoice,
    InvestmentTreatment? investmentTreatment,
    String? investmentTreatmentCustomLabel,
    bool? reduceMotion,
    bool? hapticsEnabled,
    bool? appLockEnabled,
    bool? biometricEnabled,
    bool? screenSecurityEnabled,
    bool? notificationsEnabled,
    bool? paymentRemindersEnabled,
    bool? thresholdAlertsEnabled,
    bool? dailyRecordRemindersEnabled,
    ReminderFrequency? reminderFrequency,
    int? reminderHour,
    int? reminderMinute,
    int? reminderWeekday,
    int? reminderDayOfMonth,
    bool? numberFormatCompact,
  }) {
    return SettingsState(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      userName: userName ?? this.userName,
      userNickname: userNickname ?? this.userNickname,
      userAge: clearAge ? null : (userAge ?? this.userAge),
      userPhone: userPhone ?? this.userPhone,
      userEmail: userEmail ?? this.userEmail,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      localeCode: localeCode ?? this.localeCode,
      dateFormat: dateFormat ?? this.dateFormat,
      financialMonthStartDay:
          financialMonthStartDay ?? this.financialMonthStartDay,
      themeVariant: themeVariant ?? this.themeVariant,
      accent: accent ?? this.accent,
      fontChoice: fontChoice ?? this.fontChoice,
      investmentTreatment: investmentTreatment ?? this.investmentTreatment,
      investmentTreatmentCustomLabel: investmentTreatmentCustomLabel ??
          this.investmentTreatmentCustomLabel,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      screenSecurityEnabled:
          screenSecurityEnabled ?? this.screenSecurityEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      paymentRemindersEnabled:
          paymentRemindersEnabled ?? this.paymentRemindersEnabled,
      thresholdAlertsEnabled:
          thresholdAlertsEnabled ?? this.thresholdAlertsEnabled,
      dailyRecordRemindersEnabled:
          dailyRecordRemindersEnabled ?? this.dailyRecordRemindersEnabled,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      reminderWeekday: reminderWeekday ?? this.reminderWeekday,
      reminderDayOfMonth: reminderDayOfMonth ?? this.reminderDayOfMonth,
      numberFormatCompact: numberFormatCompact ?? this.numberFormatCompact,
    );
  }

  Map<String, Object?> toMap() => {
        'onboardingComplete': onboardingComplete,
        'userName': userName,
        'userNickname': userNickname,
        'userAge': userAge,
        'userPhone': userPhone,
        'userEmail': userEmail,
        'cloudSyncEnabled': cloudSyncEnabled,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'localeCode': localeCode,
        'dateFormat': dateFormat,
        'financialMonthStartDay': financialMonthStartDay,
        'themeVariant': themeVariant.name,
        'accent': accent.name,
        'fontChoice': fontChoice.name,
        'investmentTreatment': investmentTreatment.name,
        'investmentTreatmentCustomLabel': investmentTreatmentCustomLabel,
        'reduceMotion': reduceMotion,
        'hapticsEnabled': hapticsEnabled,
        'appLockEnabled': appLockEnabled,
        'biometricEnabled': biometricEnabled,
        'screenSecurityEnabled': screenSecurityEnabled,
        'notificationsEnabled': notificationsEnabled,
        'paymentRemindersEnabled': paymentRemindersEnabled,
        'thresholdAlertsEnabled': thresholdAlertsEnabled,
        'dailyRecordRemindersEnabled': dailyRecordRemindersEnabled,
        'reminderFrequency': reminderFrequency.name,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'reminderWeekday': reminderWeekday,
        'reminderDayOfMonth': reminderDayOfMonth,
        'numberFormatCompact': numberFormatCompact,
      };

  factory SettingsState.fromMap(Map<String, Object?> m) {
    T pick<T>(T Function(String) parse, Object? raw, T fallback) {
      if (raw is! String) return fallback;
      try {
        return parse(raw);
      } catch (_) {
        return fallback;
      }
    }

    return SettingsState(
      onboardingComplete: m['onboardingComplete'] as bool? ?? false,
      userName: m['userName'] as String? ?? '',
      userNickname: m['userNickname'] as String? ?? '',
      userAge: (m['userAge'] as num?)?.toInt(),
      userPhone: m['userPhone'] as String? ?? '',
      userEmail: m['userEmail'] as String? ?? '',
      cloudSyncEnabled: m['cloudSyncEnabled'] as bool? ?? false,
      currencyCode: m['currencyCode'] as String? ?? 'INR',
      currencySymbol: m['currencySymbol'] as String? ?? '₹',
      localeCode: m['localeCode'] as String?,
      dateFormat: m['dateFormat'] as String? ?? 'MMM d, y',
      financialMonthStartDay: m['financialMonthStartDay'] as int? ?? 1,
      themeVariant: pick(
        (s) => AppThemeVariant.values.byName(s),
        m['themeVariant'],
        AppThemeVariant.system,
      ),
      accent: pick(
        (s) => AccentPreset.values.byName(s),
        m['accent'],
        AccentPreset.clay,
      ),
      fontChoice: pick(
        (s) => FontChoice.values.byName(s),
        m['fontChoice'],
        FontChoice.system,
      ),
      investmentTreatment: pick(
        (s) => InvestmentTreatment.values.byName(s),
        m['investmentTreatment'],
        InvestmentTreatment.separate,
      ),
      investmentTreatmentCustomLabel:
          m['investmentTreatmentCustomLabel'] as String? ?? '',
      reduceMotion: m['reduceMotion'] as bool? ?? false,
      hapticsEnabled: m['hapticsEnabled'] as bool? ?? true,
      appLockEnabled: m['appLockEnabled'] as bool? ?? false,
      biometricEnabled: m['biometricEnabled'] as bool? ?? false,
      screenSecurityEnabled: m['screenSecurityEnabled'] as bool? ?? true,
      notificationsEnabled: m['notificationsEnabled'] as bool? ?? false,
      paymentRemindersEnabled: m['paymentRemindersEnabled'] as bool? ?? true,
      thresholdAlertsEnabled: m['thresholdAlertsEnabled'] as bool? ?? true,
      dailyRecordRemindersEnabled:
          m['dailyRecordRemindersEnabled'] as bool? ?? true,
      reminderFrequency: pick(
        (s) => ReminderFrequency.values.byName(s),
        m['reminderFrequency'],
        ReminderFrequency.daily,
      ),
      reminderHour: (m['reminderHour'] as num?)?.toInt() ?? 22,
      reminderMinute: (m['reminderMinute'] as num?)?.toInt() ?? 0,
      reminderWeekday:
          (m['reminderWeekday'] as num?)?.toInt() ?? DateTime.monday,
      reminderDayOfMonth: (m['reminderDayOfMonth'] as num?)?.toInt() ?? 1,
      numberFormatCompact: m['numberFormatCompact'] as bool? ?? false,
    );
  }
}
