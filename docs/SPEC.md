# BudgetSense: Complete Application Specification

This document contains everything needed to recreate BudgetSense from scratch.
Hand this file plus DESIGN.md to any AI coding agent or developer and the full
application can be rebuilt with identical functionality, architecture, and design.

DESIGN.md is the single source of truth for all visual tokens (colors, type,
spacing, components). This file references it rather than repeating hex values, so
the two never drift. Where a value is behavioral (schema, logic, platform config),
it lives here in full.

---

## 1. What is BudgetSense?

A calm, offline-first personal finance journal for Android and iOS built with a
single Flutter codebase. It tracks income, expenses, investments, recurring
payments, and loans. It uses a Muji-inspired minimal design, prioritizes privacy
(all data stays on-device in SQLite), and is architected so cloud sync can be
layered on later without a rewrite.

**Core philosophy:** feel like a quiet paper journal, not a corporate banking app.

**Version:** pubspec `version: 0.11.15+33` (this is the authoritative build version).
`lib/core/constants/app_info.dart` currently mirrors it (`version = '0.11.15'`) for
the About screen, but that constant is maintained by hand, so keep the two in
sync whenever the pubspec version changes.

---

## 2. Tech Stack

Exact dependency constraints from `pubspec.yaml`:

| Concern | Package | Constraint |
|---|---|---|
| Framework | Flutter + Dart | SDK >=3.4.0 <4.0.0, Flutter >=3.22.0 (built on Flutter 3.44 / Dart 3.12) |
| State management | flutter_riverpod | ^2.5.1 |
| Navigation | go_router | ^14.2.0 |
| Local database | drift | ^2.18.0 |
| SQLite engine | sqlite3 / sqlite3_flutter_libs | ^2.4.0 / ^0.5.20 |
| Paths | path_provider / path | ^2.1.3 / ^1.9.0 |
| Formatting/i18n | intl | ^0.19.0 |
| Preferences | shared_preferences | ^2.2.3 |
| Notifications | flutter_local_notifications / timezone | ^17.1.2 / ^0.9.4 |
| Export | csv / excel / share_plus | ^6.0.0 / ^4.0.6 / ^9.0.0 |
| XML (snapshot) | xml | ^6.6.0 |
| Security | local_auth | ^2.2.0 |
| File picking | file_picker | ^8.0.5 |
| Charts | fl_chart | ^0.68.0 |
| Utilities | uuid / collection | ^4.4.0 / ^1.18.0 |
| External links | url_launcher | ^6.3.0 |
| Dev tools | flutter_lints / build_runner / drift_dev / mocktail | ^4.0.0 / ^2.4.11 / ^2.18.0 / ^1.0.4 |

**Important:** no additional pub packages are downloaded beyond the above. All
hardening and aesthetic work uses the Flutter SDK,
hand-authored vector XML, and Dart `CustomPainter` art. `xml` was promoted from an
already-resolved transitive dependency (of `excel`) to a direct one for the
snapshot XML codec, no new archive is fetched. At-rest DB encryption (SQLCipher)
is intentionally NOT added.

Android/iOS toolchain (see Sections 16 to 17): compileSdk 36, Java/Kotlin target
17, core-library desugaring on.

---

## 3. Architecture (Clean, Layered)

Full source tree (`lib/`):

```
lib/
  main.dart                          # Entry: ProviderScope + App
  app/
    app.dart                         # MaterialApp.router; theme, textScaler clamp,
                                     #   PaperTexture, WidgetSyncScope, AppLockGate,
                                     #   daily-reminder bootstrap, widget quick-add
    router.dart                      # go_router: StatefulShellRoute.indexedStack
    providers.dart                   # Core DI (database, repos, summary, calendar)
    feature_providers.dart           # Extended DI (payments, loans, thresholds,
                                     #   insights, notifications, backup, import)
  core/
    constants/
      app_info.dart                  # App name, author credits, links (About)
      branding.dart                  # kBrandMarkAsset path (enso mark for About)
      enums.dart                     # Every domain enum
      greetings.dart                 # 107 dashboard greeting templates
      reminder_messages.dart         # 15 titles + 117 emoji nudge messages
    services/
      notification_service.dart      # Local notifications + daily reminders
      widget_service.dart            # MethodChannel bridge to native widgets
      screen_security_service.dart   # Runtime FLAG_SECURE toggle (capture block)
    theme/
      app_colors.dart                # 4 palettes + 6 accent presets (see DESIGN.md)
      app_fonts.dart                 # 6 font choices + size factors
      app_spacing.dart               # Insets, Corners, Strokes, Motion tokens
      app_theme.dart                 # ThemeData builder from AppColors
      app_typography.dart            # Type scale builder
      category_icons.dart            # ~200-icon append-only set (first 12 fixed) + fallback
      paper_texture.dart             # Paper-grain overlay CustomPainter
      theme_resolver.dart            # variant+accent+font -> ThemeData pair
    utils/
      app_log.dart                   # One home for diagnostic logs (dart:developer)
      financial_calendar.dart        # Financial month, DateRange, nextOccurrence
      friendly_date.dart             # Human, locale-aware dates (Today / Tue, 28 Jul)
      greeting.dart                  # resolveDisplayName, formatGreeting
      haptics.dart                   # Central, toggle-gated haptic vocabulary
      icon_suggester.dart            # Splitwise-style icon auto-detection
      money.dart                     # Integer minor-unit money type
      reminder_schedule.dart         # Pure daily/weekly/monthly fire-time maths
    validation/validators.dart       # Shared form validation rules
  data/
    database/
      tables.dart                    # 11 Drift tables + @TableIndex
      app_database.dart              # Database class + migration strategy
      app_database.g.dart            # Generated (build_runner)
      connection.dart               # Background-isolate SQLite connection
    export/file_export_service.dart  # CSV + XLSX generation (transactions sheet)
    import/paisa_import_service.dart  # Paisa app JSON importer
    snapshot/
      snapshot_tables.dart           # Table registry + tolerant companion builders
      snapshot_codecs.dart           # JSON / CSV / XML encode+decode + auto-detect
      app_snapshot_service.dart      # Full-snapshot orchestrator (export/import)
    mappers/
      entity_mappers.dart            # Rows -> entities (non-transaction)
      transaction_mapper.dart        # Rows -> transaction entities
    repositories/
      category_repository.dart
      transaction_repository.dart
      recurring_payment_repository.dart
      loan_repository.dart
      threshold_repository.dart
      reference_repository.dart      # Accounts + PaymentMethods
      custom_field_repository.dart
    seed/default_data.dart           # Default categories + account seeder
  domain/
    entities/
      transaction_entity.dart        # TransactionEntity + CategoryEntity
      commitment_entities.dart       # RecurringPaymentEntity + LoanEntity
      config_entities.dart           # Account, PaymentMethod, CustomField, etc.
    services/
      summary_service.dart           # Pure monthly summary
      threshold_service.dart         # Threshold evaluation engine
      recurrence_service.dart        # Payment completion + loan payment logic
      insights_service.dart          # Trend, projection, averages
      reminder_planner.dart          # Notification scheduling planner
      export_service.dart            # Export abstraction + schema
      import_service.dart            # Import contracts (ImportSource, preview)
      snapshot_service.dart          # Full-app snapshot model + interface
  features/
    common/calm_widgets.dart         # CalmCard, StatTile, CalmProgressBar,
                                     #   CalmEmptyState (+ 7 line-art motifs),
                                     #   CalmFab, CalmSlider, ShimmerBlock,
                                     #   MonthNavigator
    common/feedback_widgets.dart     # SuccessCheck (self-drawing check),
                                     #   AnimatedMoneyText (count-up figure),
                                     #   BreathingPulse (calm scale pulse)
    common/brand_watermark.dart      # Faint enso watermark, paintEnsoRing +
                                     #   paintInkLeaf helpers, InkFlourish +
                                     #   FlourishTitle
    common/confetti_overlay.dart     # One-shot full-screen celebrations (CustomPainter,
                                     #   root overlay, reduce-motion aware). Variants:
                                     #   confetti / leaves / coins / firework
    common/icon_picker.dart          # Searchable icon-picker sheet + auto/edit badge
    shell/app_shell.dart             # Bottom nav (5 tabs); swipe/tap between
                                     #   sections with a subtle fade+slide
    dashboard/dashboard_screen.dart
    dashboard/mood_strip.dart        # Delight: enso mood ring + seasonal sprig +
                                     #   wallet weather; pure vibe helpers
    dashboard/quick_add_card.dart    # Accent, collapsed quick-add (name+amount+category)
    dashboard/month_calendar.dart    # Expandable paper month grid; activity dots
    expenses/expenses_screen.dart
    quick_add/quick_add_sheet.dart
    payments/
      payments_screen.dart
      payment_editor_sheet.dart
      loan_editor_sheet.dart
    insights/insights_screen.dart
    insights/insights_cards.dart     # GlanceCard, SpendingRhythmCard,
                                     #   IncomeSourcesCard, CommitmentsCard
    onboarding/onboarding_screen.dart
    export/export_screen.dart
    security/app_lock_gate.dart      # Device-lock gate, 20s re-lock grace
    widgets/widget_sync.dart         # Widget payload provider + masking
    settings/
      settings_screen.dart
      settings_controller.dart       # Persists SettingsState to SharedPreferences
      settings_state.dart            # Immutable preferences snapshot
      profile_screen.dart
      category_manager_screen.dart
      custom_field_manager_screen.dart
      reference_manager_screen.dart  # Accounts + payment methods
      threshold_editor_screen.dart
      notification_settings_screen.dart
      security_screen.dart
      backup_screen.dart             # Full snapshot export/restore (JSON/CSV/XML)
      trash_screen.dart              # Soft-deleted transactions: restore / purge
      about_screen.dart
      import/import_hub_screen.dart
      import/paisa_import_screen.dart
```

Native (see Sections 14, 16, 17): `android/app/src/main/kotlin/com/budgetsense/
budgetsense/` holds `MainActivity.kt`, `WidgetSupport.kt`, and three
`*WidgetProvider.kt` classes; `android/app/src/main/res/` holds widget layouts,
adaptive icon vectors, and light/night color and style resources.

---

## 4. Database Schema

Drift over SQLite. All 11 tables mix in an audit column set. Column names are
snake_case at the SQL layer (for example `occurredAt` -> `occurred_at`).

**Audit mixin** (`_AuditColumns`, on every table):
- `id` TEXT (UUID, primary key)
- `createdAt` DATETIME
- `updatedAt` DATETIME
- `archivedAt` DATETIME (nullable)
- `syncStatus` INTEGER (default 0), placeholder for future cloud sync

Money is always stored as INTEGER minor units, never floating point.

### Tables and columns

**Categories**: name (1-120), colorValue (INT ARGB), iconCodePoint (INT),
sortOrder (INT, 0), isDefault (BOOL, false). (A legacy `semanticBucket` TEXT
column still exists in the schema for backup back-compat but is inert: no app
logic reads it. Categories are fully dynamic and carry no fixed classification.)

**Accounts**: name (1-120), sortOrder (INT, 0).

**PaymentMethods**: name (1-120), sortOrder (INT, 0).

**Transactions**: type (INT, TransactionType index), name (1-120), amountMinor
(INT, non-negative), occurredAt (DATETIME), iconCodePoint (INT, nullable -
per-transaction icon; falls back to the category icon when null), categoryId
(TEXT FK Categories, nullable), accountId (TEXT FK Accounts, nullable),
paymentMethodId (TEXT FK PaymentMethods, nullable), incomeType (INT, IncomeType
index, nullable), merchant (TEXT, nullable), notes (TEXT, nullable), tagsJson
(TEXT, '[]'), linkedPaymentId (TEXT, nullable), linkedLoanId (TEXT, nullable).
Indexes: `idx_txn_occurred(occurredAt)`, `idx_txn_category(categoryId)`,
`idx_txn_archived(archivedAt)`. A non-null `archivedAt` is the Trash can, the
row is soft-deleted, hidden from month views but restorable (Section 11).

**RecurringPayments**: name (1-120), amountMinor (INT), kind (INT, PaymentKind),
frequency (INT, Frequency), customIntervalDays (INT, 30), startDate, endDate
(nullable), nextDueDate, categoryId (FK, nullable), accountId (FK, nullable),
notes (nullable), autoAddTransaction (BOOL, false), reminderEnabled (BOOL, true),
reminderDaysBefore (INT, 1).
Indexes: `idx_recpay_next_due(nextDueDate)`, `idx_recpay_archived(archivedAt)`.

**Loans**: name (1-120), lender (nullable), originalPrincipalMinor (INT),
outstandingPrincipalMinor (INT), emiMinor (INT), interestRateBps (INT, 0; rate
x100, e.g. 8.75% = 875), frequency (INT), startDate, endDate (nullable),
nextPaymentDate (nullable), totalPaidMinor (INT, 0), notes (nullable).
Indexes: `idx_loan_next_payment(nextPaymentDate)`, `idx_loan_archived(archivedAt)`.

**CustomFields**: name (1-120), fieldType (INT, CustomFieldType), defaultValue
(nullable), required (BOOL, false), visible (BOOL, true), displayOrder (INT, 0),
allowedValuesJson (TEXT, '[]'), appliesToJson (TEXT, '[]' of TransactionType
indices).

**CustomFieldValues**: fieldId (TEXT FK CustomFields), ownerId (TEXT), ownerType
(TEXT, e.g. 'transaction'/'loan'), value (nullable).
Indexes: `idx_cfv_owner(ownerId)`, `idx_cfv_field(fieldId)`.

**Thresholds**: label (1-160), thresholdType (INT, ThresholdType), value (REAL,
percent 0-100 or minor-unit amount), warningPercent (REAL, 0.8), criticalPercent
(REAL, 0.95), scopeKey (TEXT, nullable), enabled (BOOL, true).

**NotificationPreferences**: kind (TEXT, e.g. 'threshold_approaching',
'payment_due'), enabled (BOOL, true), timingMinutes (INT, 0), quietStartMinute
(INT, nullable), quietEndMinute (INT, nullable).

**ExportRecords**: format (TEXT, 'csv'/'xlsx'), scope (TEXT), recordCount (INT,
0), filePath (nullable).

### Migration strategy (`app_database.dart`)

- `schemaVersion => 3`.
- `onCreate`: `m.createAll()` (fresh installs get all tables plus all indexes
  from the `@TableIndex` annotations).
- `onUpgrade(from, to)`: stepwise, forward-only, idempotent. `if (from < 2)` calls
  `_createPerformanceIndexes()`, which runs nine `CREATE INDEX IF NOT EXISTS`
  statements (the nine indexes above, by exact snake_case column name).
  `if (from < 3)` runs `m.addColumn(transactions, transactions.iconCodePoint)` -
  a nullable column, so existing rows keep NULL (and fall back to the category
  icon); no data is touched.
- `beforeOpen`: `PRAGMA foreign_keys = ON;`.
- History: v1 = initial schema; v2 = performance indexes; v3 = per-transaction
  `iconCodePoint`.

`wipeAllData()` deletes every table inside a transaction in FK-safe order:
customFieldValues, transactions, recurringPayments, loans, customFields,
thresholds, notificationPreferences, exportRecords, categories, accounts,
paymentMethods.

The Settings "Delete all data" action wraps `wipeAllData()` with a best-effort
safety net: before wiping it captures a full in-memory JSON snapshot, then shows
a warm confirmation ("Everything's cleared. Fresh start.") carrying an **Undo**
action that re-imports that snapshot and calls `refreshAllDataProviders`. If the
pre-wipe snapshot cannot be taken, the wipe still proceeds, just without the Undo
affordance (forgiving, never blocking). Individual expense deletes already offer
Undo via the trash/archive path.

`connection.dart` opens SQLite on a background isolate via `sqlite3_flutter_libs`
(no encryption layer).

---

## 5. Domain Enumerations (`core/constants/enums.dart`)

In declaration order:

```dart
enum TransactionType { expense, income, investment, loanPayment, recurringPayment, custom }
enum Frequency { daily, weekly, biweekly, monthly, quarterly, halfYearly, yearly, custom }
enum PaymentKind { sip, mutualFund, recurringDeposit, fixedDeposit, insurancePremium,
                   subscription, rent, loanEmi, creditCard, utility,
                   customInvestment, customRecurring }
enum IncomeType { salary, bonus, interest, refund, reimbursement, freelance,
                  investmentReturns, other }
enum CustomFieldType { text, number, currency, percentage, date, time, toggle,
                       dropdown, multiSelect, notes }
enum ThresholdType { maxPercentage, minPercentage, maxAmount, minAmount }
enum ThresholdStatus { safe, approaching, exceeded, belowTarget, targetAchieved }
enum InvestmentTreatment { spending, savings, separate }
enum ReminderFrequency { daily, weekly, monthly }
enum SyncStatus { localOnly, pendingUpload, synced, conflict }
```

`ReminderFrequency` has a `.label` extension ("Every day" / "Every week" /
"Every month") and drives the record-expenses reminder schedule (Section 15).
Unlike enums stored as indices in the database, it is persisted by `.name` in
settings, so it is safe to extend.

There is deliberately NO fixed category classification. Categories are fully
dynamic: users add, rename, recolor, reorder and remove them under Settings, and
every feature (summary, insights, thresholds, home widgets) works off the live
category list and per-category spend (`MonthlySummary.perCategory`). The starter
set (Needs / Wants / Responsibilities) is only an optional onboarding suggestion,
fully editable, with nothing in the app depending on those names.
Enum indices are persisted in the database, so their declaration order is part of
the schema. Do not reorder.

---

## 6. Core Utilities

### Money (`money.dart`)
- Stored as `int minorUnits`. `_scale = 100`, `_fractionDigits = 2`. Never a double.
- `const Money(int minorUnits)`; `Money.fromMajor(num major)` = `Money((major*100).round())`; `static Money? tryParse(String raw, {String? locale})`.
- `static const Money zero = Money(0)`; getters `major`, `isZero`, `isNegative`, `abs`.
- Operators `+`, `-`, `*` (num factor), `compareTo` (Comparable).
- `double ratioOf(Money other)` (0 if other is zero), `double percentOf(Money other)` (= ratio*100).
- `String format({String currencySymbol = <rupee>, String? locale})`, `String formatCompact({...})` (e.g. 12.3K).
- `Money sumMoney(Iterable<Money>)` folds from `Money.zero`.
- `tryParse` strips non-numeric characters, is locale-aware for the decimal
  separator, and rejects NaN / Infinity / negatives.

### FinancialCalendar (`financial_calendar.dart`)
- `const FinancialCalendar({int monthStartDay = 1})`, asserts 1 to 28.
- `DateRange monthRangeFor(DateTime)`: inclusive range of the financial month
  containing the date.
- `String monthKeyFor(DateTime)`: stable `YYYY-MM` key (start month of period).

### DateRange
- `start`, `end`, `contains(DateTime)`, `duration`, `inclusiveDays` (= `duration.inDays + 1`).

### FriendlyDate (`friendly_date.dart`)
One home for every user-facing date so screens read like a person, not a
database. Locale-aware (via `intl` `DateFormat`, mirroring how `Money` localizes
numbers) and guarded: an uninitialized locale falls back to the default rather
than throwing.
- `relative(date, {locale, now})`: "Today" / "Yesterday" / "Tomorrow" around
  `now`, otherwise the `short` form. Each calendar day maps to a unique string
  (the year is carried whenever it differs from the current one), so it is safe
  to use as a per-day grouping key as well as a header label (Expenses does
  exactly this).
- `short(date, {locale, now})`: absolute, no relative words: "Tue, 28 Jul" in the
  current year, "28 Jul 2025" otherwise. Used where a date is read later than it
  is composed (scheduled notification bodies), so it never says a stale "Today".
- Replaces the ~8 duplicated inline `padLeft` YYYY-MM-DD formatters that used to
  live in quick-add, expenses, payments, the payment/loan editors, trash, and
  the reminder planner. Machine formats (filenames, CSV/XML columns, the
  `monthKeyFor` grouping key) deliberately stay ISO 8601.

### AppLog (`app_log.dart`)
The single place the app writes diagnostic logs, so user-facing copy can stay
warm and vague while the messy detail (exceptions, stack traces, URLs) goes to
the developer console, never into a SnackBar.
- `AppLog.error(message, {error, stackTrace})` wraps `dart:developer log` at
  SEVERE. Used by the export screen, the About links, and the data-wipe undo:
  each catches, logs the real cause via `AppLog`, and shows the user a kind line
  ("That export didn't go through. Give it another go?"). Swapping in a real
  crash reporter later is a one-file change.

### nextOccurrence(DateTime from, Frequency, {int customIntervalDays = 30})
Advances by one step: daily +1d, weekly +7d, biweekly +14d, monthly +1mo,
quarterly +3mo, halfYearly +6mo, yearly +12mo, custom +customIntervalDays. Month
math clamps to the last valid day (e.g. Jan 31 + 1mo = Feb 28).

### Validators (`validation/validators.dart`)
- `name(value, {field='Name'})`: required, max 120.
- `amount(value, {locale, allowZero=false})`: required, valid via `Money.tryParse`, non-negative, non-zero unless allowZero.
- `percentage(value)`: required, valid double, 0 to 100 inclusive. `rate(value)` aliases percentage.
- `optionalNotes(value, {max=2000})`: optional, max 2000 chars.

### ReminderSchedule (`reminder_schedule.dart`)
Pure, plugin-free description of when the record-expenses nudge fires:
`ReminderSchedule({ReminderFrequency frequency = daily, int hour = 22, int minute
= 0, int weekday = 1, int dayOfMonth = 1})`.
- `List<DateTime> occurrences({required DateTime from, required int count})`
  returns the next `count` fire-times strictly after `from`, ascending. Daily
  advances by 1 day; weekly walks to the chosen weekday then +7d; monthly uses
  `dayOfMonth` (clamped 1..28 so it exists every month) and advances one month at
  a time, rolling across year boundaries.
- `String describe()` gives a human sentence ("Every day at 10:00 PM", "Every
  Friday at 9:05 AM", "Every month on the 3rd at 12:00 AM").
- `copyWith(...)`. All maths are unit-tested (`reminder_schedule_test`).

### Haptics (`haptics.dart`)
The single home for haptic feedback, following Android's haptics principles
(restrained, meaningful, never decorative). Static, so any widget can call it
without a `ref`. A semantic vocabulary, not raw strengths:
- `selection()` (light tick): discrete choices (tabs, chips, switches, slider
  steps, month change, collapsible open/close, dashboard eye toggle, FAB press).
- `confirm()` (soft light impact): a small action landed (save, restore, backup
  done, test reminder).
- `impact()` (medium, sparing): a weightier/destructive commit (trash, empty
  trash, delete forever).
- `warning()` (heavy, rare): genuine errors.
All gated by `Haptics.enabled`, which `app.dart` keeps in sync with the
`hapticsEnabled` setting; when off, every call is a no-op. On Android the buzzes
are driven natively through a `Vibrator` method channel
(`com.budgetsense.budgetsense/haptics`, handled in `MainActivity.kt`) using
`VibrationEffect.createOneShot` with an explicit amplitude (`DEFAULT_AMPLITUDE`
when the motor lacks amplitude control; deprecated `vibrate(ms)` on API 24 to 25),
tagged `USAGE_TOUCH` on API 33+. Predefined effects (`EFFECT_TICK` etc.) are
avoided because they are silent no-ops on many OEM devices; direct `Vibrator`
calls also bypass the system touch-feedback toggle, so they fire on any device
with a motor. Flutter's built-in `HapticFeedback` is the fallback for other
platforms and any channel failure (ideal on iOS). Requires the `VIBRATE`
permission. Note: the Android emulator reports a vibrator but has no physical
motor, so haptics can only be felt on real hardware.

---

## 7. Business Logic (Domain Services, all pure, no Flutter/DB imports)

### SummaryService
`summarize(transactions, {investmentTreatment})` -> `MonthlySummary`:
totalGains, totalSpent, totalInvestments, totalLoanPayments, perCategory map (the
dynamic spend-per-category, the basis for every category breakdown), totalBalance
(depends on
InvestmentTreatment), totalSavings (= gains - spent - investments), savingsRate,
investmentRate (fractions of income, clamped 0 to 1). Income adds to gains;
investments tracked separately (never in "spent"); loan payments count as spent
AND separately; expenses/recurring/custom count as spent; archived excluded.
There are no fixed classification buckets: spend is tracked per category id only.

`positiveNote` is an optional, pure getter returning a gentle line of
encouragement for a good month (null when there is nothing to celebrate, so the
UI simply shows nothing, mirroring the negative caption). It requires real
income and a net-positive balance, then tiers the wording honestly against the
ratios: savingsRate >= 0.5, >= 0.25, investmentRate >= 0.2, else a plain
"ended the month in the green" line.

### ThresholdService
`evaluate(rule, {actual, monthlyIncome})` -> `ThresholdEvaluation`. Percentage
rules: limit = income * value / 100. Amount rules: limit = stored value. Max
rules: safe < approaching (warning/critical) < exceeded (at 100%). Min rules:
belowTarget < approaching (at warningPercent) < targetAchieved (at 100%).

### RecurrenceService
- `complete(payment, {newTransactionId})`: marks paid, optionally creates a
  transaction, advances the schedule, archives if past end date.
- `payLoan(loan, {newTransactionId})`: pays `min(emi, outstanding)` so the final
  installment never records more than what is owed; reduces outstanding (clamped
  to >= 0), bumps totalPaid by the actual amount paid, advances nextPaymentDate,
  creates a loan-payment transaction for the actual amount.
- `overdue(payments, now)`: due before today. `upcoming(payments, now, {days:7})`.

### InsightsService
- `trend(transactions, {calendar, months:6})` -> MonthPoint series.
- `averageDailySpend(totalSpent, DateRange)`: divide across inclusive days.
- `projectedMonthEndBalance({income, spentSoFar, invested, monthRange, now})` -
  extrapolates the daily spend rate across the full month.
- `momSpendChange(List<MonthPoint>)`: fractional change vs previous month.

### ReminderPlanner
- `planForPayments(payments, {now})`: a ScheduledAlert per enabled, non-archived
  payment, `reminderDaysBefore` days before due; skips alerts older than now-1d.
- `planForLoans(loans, {now})`: alert 1 day before each loan's nextPaymentDate.
- Stable ids: `key.hashCode & 0x7fffffff` (loans keyed `'loan_<id>'`), so
  rescheduling replaces the prior notification.

### ExportService / ImportService
Interfaces plus schema. ExportSchema projects transaction rows in a fixed header
order and filters by scope. ImportService defines `ImportSource { paisa }`,
`inspect(...) -> ImportPreview`, `import(...) -> ImportOutcome`.

Durable full-app backup/restore lives in SnapshotService (Section 11), not a
separate backup service. Cloud sync is a stored user preference only (a "coming
soon" toggle); there is no sync service abstraction in code yet, and every row
carries a `syncStatus` column so one can be layered on later without migration.

---

## 8. Provider Graph (Riverpod DI)

**Core (`providers.dart`):** databaseProvider (singleton AppDatabase),
transactionRepositoryProvider, categoryRepositoryProvider, summaryServiceProvider
(const), thresholdServiceProvider (const), financialCalendarProvider (from
settings.monthStartDay), focusedMonthProvider (StateProvider<DateTime>),
categoriesStreamProvider, monthTransactionsProvider (focused month),
monthlySummaryProvider (SINGLE SOURCE OF TRUTH; transactions + categories +
settings), plus previousMonthTransactionsProvider / previousMonthSummaryProvider
(the financial month before the focused one; both built through the shared
`_summarize` helper, used only by the firework celebration).

**Feature (`feature_providers.dart`):** repositories for recurring payments,
loans, accounts, payment methods, custom fields, thresholds; services for
recurrence, export, notifications, reminder planner, backup, snapshot, insights,
import; streams for each entity (plus archivedTransactionsProvider and the
FutureProvider trailingTransactionsProvider); derived overduePaymentsProvider,
thresholdEvaluationsProvider (all enabled rules vs
current summary), thresholdWarningsProvider (non-safe only), insightsTrendProvider
(6 months). It also exposes `refreshAllDataProviders(WidgetRef)`, the DRY helper
that invalidates every database-backed provider after a bulk mutation (snapshot
restore, Paisa import) so restored data appears without an app restart
(Section 14, Post-restore visibility).

**Widgets (`widget_sync.dart`):** `widgetPayloadProvider` (autoDispose) computes
current-month figures as pre-formatted strings, masking financial keys when app
lock is on; `WidgetSyncScope` pushes every change to native widgets.

---

## 9. Navigation

`go_router` with `StatefulShellRoute.indexedStack` (each tab keeps its own state
and scroll position; a root navigator key allows overlays like the widget-driven
quick add):

- `/onboarding`: first-run flow.
- `/dashboard` (tab 0), `/expenses` (1), `/payments` (2), `/insights` (3),
  `/settings` (4), plus pushed sub-routes under settings.

Redirect: while settings are loading the router is not built, so the first
redirect sees the real `onboardingComplete`. If false, redirect to `/onboarding`
(no flash, no tab-tap needed).

---

## 10. Settings System

`SettingsController` persists `SettingsState.toMap()` as a single JSON blob in
SharedPreferences under key `budgetsense.settings.v1`. Fields with defaults:

| Field | Type | Default |
|---|---|---|
| onboardingComplete | bool | false |
| userName | String | '' |
| userNickname | String | '' |
| userAge | int? | null |
| userPhone | String | '' |
| userEmail | String | '' |
| cloudSyncEnabled | bool | false |
| currencyCode | String | 'INR' |
| currencySymbol | String | (rupee symbol) |
| localeCode | String? | null |
| dateFormat | String | 'MMM d, y' |
| financialMonthStartDay | int | 1 |
| themeVariant | AppThemeVariant | system |
| accent | AccentPreset | clay |
| fontChoice | FontChoice | system |
| investmentTreatment | InvestmentTreatment | separate |
| reduceMotion | bool | false |
| hapticsEnabled | bool | true |
| appLockEnabled | bool | false |
| biometricEnabled | bool | false |
| screenSecurityEnabled | bool | true |
| notificationsEnabled | bool | false |
| paymentRemindersEnabled | bool | true |
| thresholdAlertsEnabled | bool | true |
| dailyRecordRemindersEnabled | bool | true |
| reminderFrequency | ReminderFrequency | daily |
| reminderHour | int | 22 |
| reminderMinute | int | 0 |
| reminderWeekday | int (1=Mon..7=Sun) | 1 |
| reminderDayOfMonth | int (1..28) | 1 |
| numberFormatCompact | bool | false |

Enums persist by `.name`; `fromMap` falls back to defaults on any parse error.
`copyWith` supports a `clearAge` flag. `SettingsState` exposes a
`reminderSchedule` getter that assembles the five reminder fields into the pure
[ReminderSchedule] used to compute fire-times.

---

## 11. Feature Specifications

### Onboarding (5 pages, skippable)
1. Welcome ("Hi there"), privacy promise, author credit.
2. Profile, required first name (validated; "A first name is all I need to
   continue."); optional nickname, age, phone, email.
3. Money, currency symbol (max 4 chars) and financial month start day (1-28).
4. Cloud sync, a disabled "coming soon" toggle (placeholder).
5. Defaults, toggle to seed starter categories and thresholds.
"Maybe later" (top right) always seeds default categories so the app is usable
immediately.

### Dashboard
Order: greeting header (personalized), month header, balance card, "Where it
went" breakdown (collapsible), rates (collapsible), payments card (collapsible),
per-screen FAB. The home screen is deliberately quiet: only the balance is shown
by default and secondary sections start collapsed. Threshold warnings ('Attention')
live on the Insights screen, not here.
- **Month header** (`_monthHeader`): left/right chevrons and a horizontal swipe
  change the focused month (never into the future); a "today" shortcut appears
  off the current month. Tapping the month name toggles an expandable
  `MonthCalendar` open **and** closed (chevron rotates; `ClipRect` + `AnimatedSize`
  animate the reveal from the header). The calendar dots each day with activity
  (sage = net-positive, clay = net-outflow), rings today, and shows a per-day
  summary when a day is tapped.
- Balance uses `textPrimary` (neutral, never red) and is **always visible**. When
  negative, a quiet caption: "You've spent a little more than you earned this
  month." When net-positive, the counterpart `summary.positiveNote` shows a
  gentle, ratio-honest line with a small sage `spa` icon (celebrating good
  months as gracefully as it handles hard ones), so the emotional read runs both
  directions.
- **First-run / empty-month dashboard**: when the focused month has no
  transactions, the whole card stack is replaced by an `enso` `CalmEmptyState`
  (copy adapts for the current month vs a past empty month); the greeting and
  month navigator stay so navigation still works.
- **Privacy eye-toggle**: the balance card header carries an eye button. The
  three sub-figures (Income, Spent, Invested) are hidden behind a heavy blur
  (`ImageFilter.blur`, sigma 14, unreadable, not merely dimmed) until revealed;
  the blurred figures are wrapped in `ExcludeSemantics` so screen readers never
  announce hidden amounts. The reveal state is session-scoped (re-hides on
  relaunch) and toggling gives haptic feedback.
- **Collapsible sections** (`CollapsibleCard`): "Where it went" and "Rates"
  start collapsed to keep the screen calm. A tappable header (rotating chevron,
  `AnimatedSize` body) expands each.
- **Payments card** (`_PaymentsCard`): the dashboard is strictly the current
  month, so this shows only what is due now (the `overduePaymentsProvider`
  list), never a future window. When nothing is due it becomes a calm
  "Nothing due right now. Breathe easy." card (sage check) that is **always**
  shown, so the delight below is always reachable.
  **Easter egg:** double-tapping the all-clear card fires a full-screen
  celebration (`ConfettiOverlay.shower`, a dependency-free `CustomPainter` root
  overlay that plays once and removes itself, wrapped in `IgnorePointer`, no-op
  under reduce-motion). The variant is chosen by the pure `celebrationVariant`
  helper (`dashboard/mood_strip.dart`): **firework** when this month's savings
  rate beats last month's (via `previousMonthSummaryProvider`), **coins** when a
  loan is fully repaid, **leaves** in Sep..Nov, else the classic **confetti**.

### Delight layer (purely aesthetic, all reduce-motion aware)
Everything here is non-functional on purpose: craft you can screenshot, not
controls.
- **Mood strip** (`dashboard/mood_strip.dart`, one plain `CalmCard` under Quick
  Add, no watermark):
  - **Enso mood ring** (`EnsoMoodRing`): a hand-brushed enso that fills as the
    month's savings rate climbs toward its target, closing into a near-complete
    circle (with a warm accent bead at the brush tip and a soft positive halo)
    when the target is met. Center shows the saved percentage. Animated via
    `TweenAnimationBuilder` (instant under reduce-motion). Target comes from the
    pure `savingsTarget` (first enabled `minPercentage` threshold, else 20%).
    **Easter egg:** long-press the ring and the app brushes one complete enso
    for you (it blooms to full with a soft positive halo, then eases back to
    your real progress). Under reduce-motion it just gives a gentle haptic.
  - **Seasonal sprig** (`_SprigPainter`): grows one almond leaf per no-spend
    day this month (capped at 6 leaves visually, count in the caption), a crown
    bud once at least one clean day exists. Backed by pure
    `noSpendDaysThisMonth` (distinct days with an expense that is not an
    investment, from the 1st through today).
  - **Wallet weather** (`_WeatherPainter` + pure `classifyWeather`): a
    hand-drawn sun / sun-behind-cloud / cloud / cloud-with-drizzle from balance
    sign and savings rate. Sunny >= 20%, fair >= 5%, cloudy otherwise, drizzle
    when the balance is negative. "Sunny, with a chance of chai."
- **Confetti variants** (`common/confetti_overlay.dart`, `ConfettiVariant`):
  falling paper `confetti`, autumn `leaves` (almond leaves with a centre vein),
  soft `coins` (rimmed gold discs), and a radial `firework` burst (streaked
  sparks with a little gravity). Each has its own palette, piece count and
  duration; the firework uses a separate radial painter.
- **Breathing balance** (`BreathingPulse`, `common/feedback_widgets.dart`): when
  the month is genuinely calm (current month, positive balance, nothing
  overdue), the balance figure breathes with a ~1.5% scale pulse anchored left.
  Perfectly still under reduce-motion.
- **Ink flourishes** (`InkFlourish` / `FlourishTitle`, `common/brand_watermark.dart`):
  a short hand-drawn wavy accent underline beneath section titles (used on the
  mood strip's "A feeling for the month"). Paper grain itself is handled
  app-wide by `PaperTexture` (`core/theme/paper_texture.dart`) which already
  lays a seeded speck-and-fibre texture over the whole UI, so cards do not add
  their own. Dashboard cards themselves carry no per-card enso/app-mark
  branding; the home screen stays clean.
- **Greeting re-roll** (`_GreetingHeader`): the dashboard greeting is otherwise
  fixed for the session. **Easter egg:** long-press it for a soft haptic and a
  fresh hello from the `dashboardGreetings` pool (`ref.invalidate`).
- **Quick add card** (`dashboard/quick_add_card.dart`): an accent-coloured,
  collapsed-by-default card just under the balance (no app-mark branding).
  Expanding reveals a soothing "just get
  it done" form: expense name + amount + category, always dated today. Submitting
  writes a `TransactionType.expense` straight through `TransactionRepository`.
  The full sheet (the + FAB) remains for everything else.

### Quick Add (bottom sheet, `QuickAddSheet.show`)
Fields: type chips (all TransactionType), name (required), amount (currency
prefix, required), an **icon chooser** beside the name, income-type dropdown
(income only), category dropdown (non-income), date picker (defaults now;
future-month warning), notes (optional, max 2 lines). The icon chooser
auto-suggests an icon from the name as the user types (`IconSuggester`, Section
11, Icons) and can be overridden via the searchable picker; once overridden it
stops auto-changing. Reused for create and edit (`existing` param). `defaultNote`
param is applied silently only if the notes field is left empty (used by the
home-screen quick-add widget, note text "Expense Added through BudgetSense Widget").
While the category list loads, the dropdown shows a calm `ShimmerBlock`
(56 high) rather than a raw progress bar, keeping the sheet on-aesthetic. On save
the sheet briefly shows a `SuccessCheck` then closes; the Save button reads
"Saving…" (a real ellipsis, consistent with the loan and payment editors).

### Expenses
Search (name + notes), horizontal type filter chips (All + each type), sort popup
(newest, oldest, amount high-low, amount low-high), group-by-date toggle,
long-press multi-select with bulk delete, swipe-to-delete, tap to edit,
popup menu (edit / duplicate / move to trash). Each row shows a leading circular
icon: the transaction's own `iconCodePoint` if set, otherwise its category icon,
otherwise a neutral fallback, tinted by the category color. Duplicate creates a
copy with a new id and current timestamp. Empty state uses
`CalmIllustration.wallet`.

**Delete is soft (Trash), not destructive.** Swipe-left, bulk delete, and the
row menu all call `repo.archive()` (sets `archivedAt`) and show a 10-second
"Moved to Trash" snackbar with **Undo**. Items live in the Trash until restored
or permanently removed (Section 11, Trash).

### Trash (`settings/trash_screen.dart`)
Reached from Settings > Data > Trash. Lists archived (soft-deleted) transactions
newest-first via `archivedTransactionsProvider` (`repo.watchArchived()`), each
with **Restore** (`repo.unarchive`) and **Delete forever** (`repo.delete`, with a
confirm dialog). An **Empty** action (`repo.emptyTrash`) permanently clears all
archived rows after confirmation, then shows a warm "Trash emptied. A clean
slate." snackbar; the live (non-archived) data is never touched.
Empty state (`CalmIllustration.sprig`) and a short hint explain the 10-second
undo / trash flow. Trash is included in every backup (archived rows are
exported) and restored as trash on import, so soft-deletes survive
backup/restore round-trips.

### Payments (two tabs)
- Recurring: the working list shows only occurrences due through the end of the
  current month (`FinancialCalendar.monthRangeFor(now).end`), sorted soonest
  first. "Mark paid" calls `RecurrenceService.complete` and upserts; because
  completing advances the due date past month-end, the row slides out of the
  working list. Once nothing is left due this month, an `_AllCaughtUpCard`
  ("All paid for <month>") replaces the list. Everything due after this month is
  tucked into a collapsed **Upcoming** `CollapsibleCard` (`_UpcomingSection`),
  grouped by "Month Year", read-only rows (tap to edit). When a new month
  starts, that month's rows move from Upcoming into the working list. Extended
  FAB "Payment"; empty state uses `CalmIllustration.calendar`. Auto-adding
  payments also "recreate themselves" each period: on launch
  `catchUpRecurringPayments` (in `feature_providers.dart`) calls
  `RecurrenceService.catchUp`, which posts every period that has come due since
  the last open and advances the schedule. Manual (non auto-add) payments are
  left for the user to "Mark paid". Idempotent: two opens in one day post
  nothing extra.
- Loans: an **expandable card** (collapsed by default) showing outstanding/
  original, EMI and repayment progress. Expanding reveals the last EMI recorded
  (amount + date + time, from `lastLoanPaymentProvider` /
  `TransactionRepository.latestForLoan`), an optional **custom amount** field
  (blank = the EMI), a date/time picker (defaults to now), a "Record EMI" button
  and an "Edit loan" link. Recording calls `RecurrenceService.payLoan(amount:,
  paidAt:)`; the custom amount is clamped to what is still owed. Extended FAB
  "Loan"; empty state uses `CalmIllustration.coin`.

### Insights
**Attention** card at the top, non-safe threshold evaluations (icon + label,
color-independent); hidden when everything is within limits. Evaluations are
deduped by scope + type + target value in `thresholdEvaluationsProvider`, so an
identical rule can never be reported twice (regardless of how a duplicate got
into the store). Then income vs expenses vs savings; a **This month at a glance**
card (`GlanceCard`: expense count, average size, biggest expense); top 5 spending
categories; a **Spending rhythm** card (`SpendingRhythmCard`: spend per weekday
as gentle bars, calls out the busiest day); a **Where income came from** card
(`IncomeSourcesCard`: income grouped by `IncomeType`, hidden when none); 6-month
trend with MoM change (trending_up/down icon); a **Money you've committed** card
(`CommitmentsCard`: active recurring count + total, outstanding loan balance,
combined EMI); average daily spend; projected month-end balance (neutral
`textPrimary`, with early-month and negative captions, see DESIGN.md). The deeper
cards live in `insights/insights_cards.dart` (keeps `insights_screen.dart` short)
and are backed by pure helpers on `InsightsService`: `spendByWeekday`,
`expenseStats`, `incomeByType`.

### Settings
Grouped into clean categories: Profile, Appearance (theme variant, accent, font
picker with live preview, reduce motion, haptic feedback), Money & display
(currency symbol, month start day, investment treatment, compact numbers), Manage
(categories, accounts/payment methods, custom fields, thresholds, notifications),
Data (export, backup/restore, import, trash), Privacy & security (app lock, screen
capture protection toggle), Danger zone (delete all data with confirm), About.

**Search.** A field at the top filters an `_index` of `_SearchItem`s by label,
section, or keywords. Each result knows how to reach its setting: inline controls
(theme, accent, currency, ...) carry a `target` `GlobalKey` and tapping them
clears the query, scrolls to the section (`Scrollable.ensureVisible`, waiting two
frames for the rebuilt list) and briefly highlights it; sub-pages (categories,
backup, notifications, security, about, ...) carry an `open` callback and tapping
them navigates straight to that screen. This makes every setting reliably
reachable by name or synonym.

### Category Manager
Add/edit name, color (8-swatch palette, see DESIGN.md), and icon via the
searchable icon picker over the ~200-icon `kCategoryIcons` library. As the user
types a category name the icon auto-suggests (`IconSuggester`) until they pick one
manually. Reorder (ReorderableListView), set default, archive, delete with
replacement (if in use, pick a replacement first).

### Icons (`core/theme/category_icons.dart`, `core/utils/icon_suggester.dart`, `features/common/icon_picker.dart`)
- **Library.** `kCategoryIcons` is an append-only list of ~200 outlined Material
  icons. Append-only matters: categories and transactions store an icon **code
  point**, and the first 12 indices are preserved so pre-existing data keeps its
  icon. `categoryIcon(codePoint)` resolves a code point back to an `IconData`,
  falling back to `kFallbackCategoryIcon`.
- **Auto-detect (Splitwise-style).** `IconSuggester.suggestCodePoint(text)` maps
  free text to an icon via an ordered keyword ruleset (groceries, coffee, Uber,
  fuel, rent, SIP, insurance, recharge, pharmacy, school, donation, ...). Rules
  are ordered so specific matches win (e.g. insurance is checked before loan
  because "premium" contains the substring "emi"). Every returned code point is
  guaranteed to exist in `kCategoryIcons`.
- **Manual override.** `IconChoiceButton` shows the current icon and an
  auto/edit badge; `showIconPickerSheet` is a searchable draggable grid (6
  columns) backed by `IconSuggester.searchCodePoints`. Editors set an
  `_iconTouched` flag on manual selection so auto-suggest stops overriding the
  user's choice.

### Thresholds (`threshold_editor_screen.dart`)
Full CRUD. Type max/min percentage or max/min amount, value, warning and critical
percent sliders, scope dropdown (Investments, Unallocated, any of the user's own
categories by id/name, or none). The category options are built live from the
category list, so the scope choices are fully dynamic. Enable/disable in the list.

### Export
CSV or XLSX; scope All / This month / Expenses / Income / Investments; preview
(first 20 rows); export opens the native share sheet; logs an ExportRecord.

### Backup and Restore (`backup_screen.dart`)
The live Backup & restore screen uses the **complete snapshot** subsystem
(Section 23), not the legacy DB-only backup. The user picks a format (JSON / CSV /
XML) and "Create backup" exports EVERYTHING (all tables plus all settings /
profile / theme / accent / font / app-icon). "Restore from file" accepts any file,
auto-detects the format, restores the data and settings, and reapplies the chosen
launcher icon. The confirm dialog warns that same-id records are overwritten and
current settings are replaced.

**Post-restore visibility.** After a successful restore the screen reads
`repo.latestActiveDate()` and sets `focusedMonthProvider` to that month, then
calls `refreshAllDataProviders(ref)`. Two things had to be true for restored data
to appear without an app restart: (1) the dashboard and expenses list always open
on the current financial month, so data from an older month would be invisible
until the user paged back, and (2) after a bulk restore the long-lived,
non-autoDispose stream providers (kept alive off-stage in the shell IndexedStack)
did not always re-emit for the current session. Jumping to the latest month with
data solves (1); invalidating every database-backed provider in one shot solves
(2). Together the restore is visible instantly, sitting alongside any manually
added records. The same `refreshAllDataProviders` call is made after a Paisa
import.

`refreshAllDataProviders(WidgetRef)` (feature_providers.dart) is the single, DRY
list of data-backed providers to invalidate: monthTransactions, archived,
categories, trailing, recurring payments, loans, accounts, payment methods,
custom fields, thresholds. Derived providers (summaries, threshold evaluations,
overdue/upcoming) rebuild automatically because they watch these.

The old DB-only JSON backup writer (`local_backup_service.dart`, `version: 2`, 11
tables, no settings) has been removed: SnapshotService is the only backup writer
now. Backups produced by those old app versions are still restorable, because
the snapshot importer (`snapshot_codecs.dart`) detects and reads the legacy
v1/v2 shape directly.

### App icon
One fixed launcher icon: the ensō brand mark on warm cream paper. Android uses a
single adaptive icon (safe-zoned foreground + cream background) with legacy square
and round fallbacks; iOS uses the opaque ensō at every required size. Every icon
ships as a committed raster PNG at each required density, so the mark is identical
and crisp everywhere. There is no in-app icon picker.

### In-app branding
The transparent ensō mark (`assets/branding/budgetsense_mark.png`, registered
under `flutter.assets`) is shown as the header on the About screen and the
onboarding welcome page via `kBrandMarkAsset`.

### Import (Paisa)
`paisa_import_service.dart` imports a Paisa app JSON export. Append-only
(`insertOrIgnore`, idempotent, atomic batch, 500-row chunks). Reuses Paisa UUIDs
as ids to preserve links; remaps foreign icon code points to `kCategoryIcons` by
category name; maps 23 currency codes to symbols. Paisa types: 0 expense,
1 income, 2 transfer (skipped). Defaults for missing fields (color `#7E97A6`,
"Imported category"/"Imported account", amount 0, datetime now). Two-step UX:
`inspect` (preview counts) then `import` (with optional profile import).

### Security
Device-lock handoff only (see Section 13). A single "App lock" toggle; enabling it
verifies the device lock once via `LocalAuthentication` so the user is never
stranded. No in-app PIN UI.

### Notifications
Master toggle (permission requested on first enable). When on, four things are
configurable: the **record-expenses reminder** (with a schedule editor, below),
payment/EMI reminders, threshold alerts, plus a "Send a test" button and a
"Reschedule" button. See Section 15.

**Record-expenses reminder schedule.** By default there is exactly one nudge:
every day at 10:00 PM (22:00) local time. The user can change the cadence with a
`ReminderFrequency` chip group (Every day / Every week / Every month) and pick
the time via `showTimePicker`. A weekly schedule adds a weekday chooser (Mon..Sun
chips); a monthly schedule adds a day-of-month dropdown (1..28, capped so the day
exists in February). The card subtitle shows a plain-English summary, e.g. "Every
day at 10:00 PM" (`ReminderSchedule.describe()`). Any change re-schedules the
nudges immediately. All controls fire a subtle `Haptics.selection()`.

---

## 12. Default Seed Data (`data/seed/default_data.dart`)

When onboarding completes with defaults enabled:

**Starter categories** (optional suggestion only; isDefault true only for the
first; all fully editable and removable; nothing depends on these names):
| Name | colorValue | Icon (kCategoryIcons index) | sortOrder |
|---|---|---|---|
| Needs | `0xFF7E97A6` | 0 (home_outlined) | 0 |
| Wants | `0xFFB07C5E` | 1 (star_outline) | 1 |
| Responsibilities | `0xFF7B7F52` | 2 (account_balance_outlined) | 2 |

**Account:** `Cash` (sortOrder 0). No default payment methods.

**Suggested thresholds**. Two layers, both fully editable:

1. App-level, category-agnostic (`SuggestedThresholds.defaults()`, warningPercent
   0.8 / criticalPercent 0.95 unless noted). These make sense for anyone
   regardless of which categories they create:
   - Invest at least 15% (minPercentage, scope investments; warning 0.85, critical 1.0)
   - Unallocated within 20% (maxPercentage, scope unallocated)

2. Starter-category thresholds (`starterCategoryThresholds`, built in
   `default_data.dart`). These are seeded ONLY when the user opts into the
   starter categories during onboarding, and each is scoped to the created
   category's real, dynamic id (never a name) and merely labelled with its
   current name (`"<name> under X%"`, maxPercentage): Needs 50%, Wants 30%,
   Responsibilities 35%. The percentages live as data attached to the starter
   category definitions; if the user declines the starter set, these thresholds
   never exist. If the user later renames or deletes a category, the rule keeps
   working (or harmlessly resolves to zero) via its stored id. This is the ONLY
   place Needs/Wants/Responsibilities get any threshold, and even then purely by
   dynamic id, so nothing in the app depends on those names.

The seeder (`DefaultDataSeeder.seedIfEmpty` / `seedDefaults`) mints category ids
up front and returns the created `SeededCategory` records so onboarding can seed
layer 2. Threshold seeding is gated behind the same opt-in toggle as the starter
categories, so declining leaves you with zero name-based thresholds.

Ids are UUIDs.

---

## 13. Security and Privacy Model

- **App lock = device lock handoff.** `AppLockGate` wraps the app. When
  `appLockEnabled`, it calls `LocalAuthentication.authenticate` with
  `biometricOnly: false` and `stickyAuth: true`, so fingerprint, face, pattern, or
  the device PIN all unlock. BudgetSense keeps no PIN of its own.
- **Auto-lock re-lock grace.** `AppLockGate` is a `WidgetsBindingObserver`. On
  pause/hidden it records the time; on resume it re-locks only if away for
  `>= 20 seconds` (`_relockGrace`). Brief task-switches do not force re-auth.
- **FLAG_SECURE (user-toggleable).** `MainActivity.onCreate` sets `FLAG_SECURE`
  unconditionally so the app starts secured (blocks screenshots, screen
  recording, and the recent-apps thumbnail). A `setScreenSecure` method channel
  call then reconciles it to the `screenSecurityEnabled` preference on startup
  and on every change: `ScreenSecurityService.setSecure` (invoked from
  `app.dart`) `addFlags`/`clearFlags` at runtime. On by default; the user can
  disable it in **Settings > Privacy & security > Screen capture protection** to
  take screenshots or record the app. The preference travels in every snapshot
  backup.
- **No device backup.** Manifest `android:allowBackup="false"`,
  `android:fullBackupContent="false"`, and `android:dataExtractionRules=
  "@xml/data_extraction_rules"`, which excludes every domain (sharedpref,
  database, file, external, root) from both cloud-backup and device-transfer.
- **Widget privacy.** When `appLockEnabled`, `widget_sync.dart` masks every
  financial figure to the bullet string before it reaches the home screen; the
  sensitive key set is `kSensitiveWidgetKeys` (balance, income, spend, invested,
  savingsRate/Num, investmentRate/Num, avgDailySpend, projectedBalance, the four
  indexed top-category values/percents `cat{1..4}Value` / `cat{1..4}Pct`,
  runwayNote, nextDueAmount, expenseAverage, biggestAmount, spendGrid).
  Category *labels* and the motivating `footerText` stay visible because they are
  not figures.
  Metadata (currencySymbol, monthLabel,
  updatedAt) stays so the widget still shows the month.
- iOS `NSFaceIDUsageDescription`: "BudgetSense uses Face ID to unlock the app so
  only you can see your finances."
- No cloud calls in v1. All data is local. No raw PIN or secret is ever logged.

---

## 14. Home-screen Widgets (Android)

Eleven `AppWidgetProvider`s registered as exported receivers in the manifest,
each with an `APPWIDGET_UPDATE` filter and an `appwidget-provider` meta-data xml.
The No-spend graph goes beyond static text: a home screen cannot host a custom
View, so its grid is drawn to a `Bitmap` and pushed into an `ImageView`, and it
renders however many trailing weeks fit the current width (redrawn on resize via
`onAppWidgetOptionsChanged`).

### Bridge
- Flutter -> native via a `MethodChannel` named
  `com.budgetsense.budgetsense/widgets`. `WidgetService.updateData(Map<String,
  String>)` invokes `updateWidgets`; native writes the strings into
  SharedPreferences (`WidgetSupport`, prefs file `budgetsense_widget`) and
  broadcasts an update to all providers.
- Launch actions: native stores a pending action from the launching intent
  (`WidgetSupport.EXTRA_ACTION` = `widget_action`, value `quick_add`). Flutter
  calls `consumeLaunchAction` on cold start and registers a runtime listener via
  `setActionListener` (`onWidgetAction`). `app.dart` opens the quick-add sheet on
  `quick_add` once onboarding is complete.
- `WidgetService` is guarded to Android only; no-ops on web/iOS.

### Payload keys (SharedPreferences, pre-formatted strings)
`currencySymbol`, `monthLabel`, `balance`, `income`, `spend`, `invested`,
`savingsRate`, `investmentRate`, `avgDailySpend`, `projectedBalance`,
`updatedAt`, plus the dynamic top-category bars: `catCount` and
`cat1Label`..`cat4Label` / `cat1Value`..`cat4Value` / `cat1Pct`..`cat4Pct`
(the month's biggest spending categories by whatever name the user gave them,
bars scaled to the biggest via `relativePercents`; empty rows are hidden). Plus
focused-widget extras: `balanceNote`, `balancePositive`,
`savingsRateNum` / `investmentRateNum` (0..100 for the
rate bars), `runwayNote`, `nextDueName` / `nextDueAmount` / `nextDueWhen`
(soonest commitment via pure `soonestDue` across recurring payments and loans),
and `expenseCount` / `expenseAverage` / `biggestName` / `biggestAmount`
(`InsightsService.expenseStats`), plus `spendGrid` (the GitHub-style
spend-activity graph: a column-major string of ~53 weeks of per-day intensity
levels 0..4 with `.` for future days, from the pure `buildSpendGrid`), plus
`spendMonths` (pipe-joined month labels, one per week, for the calendar header)
and `footerText` (the daily rotating, name-aware motivating footer line from
`spendFooterMessage`; metadata, not a figure, so it stays visible even when
locked) and `widgetTransparent` (metadata: true when the app is on the glass
theme, so the spend-activity widget renders transparent to match). Financial keys
(including the category values/percentages, runway, next-due amount, glance
figures and `spendGrid`, which reveals your spending shape) are masked
when app lock is on (Section 13). Category labels are names, not figures, so they
stay visible.

### Widgets and layouts
- **Dashboard** (`widget_dashboard.xml`, minWidth 250dp, minHeight 110dp): the
  kitchen-sink card; balance + income/spend/invested; the "Where it went" rows
  (top categories, dynamic) show when minHeight >= 180dp. Tap opens the app.
- **Insights** (`widget_insights.xml`, minWidth 180dp, minHeight 110dp): income
  vs expenses; rates + avg daily + projection when minHeight >= 170dp.
- **Quick Add** (`widget_quick_add.xml`, 2x1): a static "Add expense" button;
  deep-links via `quickAddIntent`.
- **Balance** (`widget_balance.xml`, 2x1): the minimalist month + balance +
  `balanceNote`.
- **Where it went** (`widget_buckets.xml`, 4x2): up to four `ProgressBar` rows
  showing the month's top spending categories (dynamic: `cat1..cat4` label +
  value + `Pct`), scaled to the biggest. Empty rows are hidden. Nothing names or
  assumes any specific category.
- **Rates** (`widget_rates.xml`, 4x2): savings (positive) and invested (info)
  rates as labelled bars driven by `savingsRateNum` / `investmentRateNum`.
- **Runway** (`widget_runway.xml`, 3x1): `avgDailySpend` + the `runwayNote`
  one-liner ("At this pace you will end July around X").
- **Next due** (`widget_next_due.xml`, 3x1): soonest recurring/EMI name, amount
  and "Due ..." / "Overdue" from `soonestDue`.
- **Quick actions** (`widget_actions.xml`, 2x2): an accent "Add expense" button
  plus a preset "Log Rs 100 chai" button. The preset fires a `quick_add_chai`
  action (`presetIntent`, request code 2) that opens the quick-add sheet
  prefilled with name "Chai" and amount 100; the user still confirms, so nothing
  is written silently.
- **This month** (`widget_glance.xml`, 4x2): expense count, average, and the
  single biggest expense.
- **Spend-activity graph** (`widget_no_spend.xml`, horizontal-resize only,
  starts ~5x2): a GitHub-contributions style grid where each square is a day,
  shaded light to dark by how many expense records fell on that day (level `0`
  none, `1` one, `2` two, `3` three-to-four, `4` five-plus), future days marked
  `.` and skipped. It is built from TWO separate components so the dimensions
  never skew: (a) the BACKGROUND is a native drawable on a `FrameLayout`
  (`widget_no_spend_card` paper card, or `widget_no_spend_glass` frosted panel),
  whose corners/edges scale cleanly; (b) the CONTENT is a transparent bitmap
  `NoSpendWidgetProvider` draws and shows with `scaleType=fitCenter`, so it
  scales UNIFORMLY (never stretched). The bitmap is
  laid out like a real contribution
  calendar: **BudgetSense branding** top-left, month labels (`spendMonths`)
  across the top, weekday labels (Mon/Wed/Fri) down a left gutter, seven rows
  Sun..Sat. A **motivating footer line** (`footerText`) sits bottom-left and a
  **Less..More legend** (the five clay swatches) sits bottom-right. The squares
  use the BudgetSense CLAY ramp (`widget_grid_l0..l4`), not green. The footer
  is name-aware: `spendFooterMessage` (in `spend_graph_footer.dart`) rotates
  daily through two 55-line pools (with-name / plain, 100+ combined), weaving in
  the onboarding nickname or name when present. Squares are small and crisp; the
  cell size follows the fixed row height and the column count follows the width,
  so the widget FILLS the width (more weeks on wider phones) but never stretches
  vertically (`resizeMode=horizontal`, `onAppWidgetOptionsChanged` redraw).
  Under the glass theme (`widgetTransparent`) the provider swaps the FrameLayout
  background to the frosted `widget_no_spend_glass` panel (macOS-glass feel: warm
  translucent frost + bright edge, NOT removed), the clay scale stays intact,
  empty cells go frosted, and text keeps a readable BudgetSense colour with a
  light halo shadow. Data comes from `TransactionRepository.watchInRange` over
  the ~53-week window; only `TransactionType.expense` records are counted per day.

All providers are registered in `WidgetSupport.providers` and the manifest, and
redraw when `WidgetService.updateData` pushes fresh figures. Bar percentages that
fail to parse (because app-lock masked them) collapse to zero, hiding the spend
shape too. Colors follow the widget palette in DESIGN.md (light
`values/colors.xml`, night `values-night/colors.xml`), with per-bucket bar
drawables (`widget_bar_info/accent/plum/negative/positive.xml`); shape drawables
(`widget_background.xml`, `widget_card_bg.xml`, `widget_button_bg.xml`) reference
`@color/widget_*` so they re-theme with system dark mode.

---

## 15. Notifications (`core/services/notification_service.dart`)

- Interface `NotificationService`: init, ensurePermission, schedule, showNow,
  cancel, cancelAll, scheduleExpenseReminders, cancelExpenseReminders.
- Impl `LocalNotificationService` (flutter_local_notifications + timezone).
  Channel id `budgetsense_reminders`, name `Reminders`.
- `ScheduledAlert { int id, String title, String body, DateTime when }`.
- **Record-expenses reminders:** driven by a pure `ReminderSchedule`
  (`core/utils/reminder_schedule.dart`) built from the user's settings. The
  service asks the schedule for the next N fire-times (30 for daily, 12 for
  weekly, 12 for monthly) and lays down one notification each, id base `900000`
  through a fixed 30-slot block so a re-schedule cancels the previous set without
  touching payment/threshold alerts. Messages and titles rotate from
  `reminder_messages.dart` (15 titles, 117 emoji-carrying messages) with a random
  start offset. Default schedule: once daily at 22:00 (10 PM). `app.dart` re-arms
  these on each cold start (guarded by `notificationsEnabled &&
  dailyRecordRemindersEnabled`; failures never crash startup).
- Payment and loan reminders are planned by `ReminderPlanner` (Section 7).

Greetings: `greetings.dart` holds 107 `{name}` templates; `greeting.dart`
resolves the display name (nickname, else first word of userName, else "there")
and substitutes `{name}`. A fresh greeting shows on each dashboard open.

---

## 16. Android Platform Config

`android/app/build.gradle.kts`:
- `namespace` / `applicationId` = `com.budgetsense.budgetsense`.
- `compileSdk = 36`; minSdk/targetSdk/versionCode/versionName from Flutter
  (versionName 0.11.15, versionCode 33).
- Java/Kotlin target 17; `isCoreLibraryDesugaringEnabled = true` with
  `desugar_jdk_libs:2.1.4`.
- Signing: `signingConfigs.release` reads `android/key.properties` (keys
  `storeFile`, `storePassword`, `keyAlias`, `keyPassword`) when present; that file
  is gitignored and absent by default, so release falls back to the debug
  keystore. Provide a real `key.properties` + keystore for distributable builds.
- `buildTypes.release`: `isMinifyEnabled = false`, `isShrinkResources = false`
  (R8 kept off until validated), `proguardFiles(getDefaultProguardFile(
  "proguard-android-optimize.txt"), "proguard-rules.pro")`, release signingConfig.
- `proguard-rules.pro` holds staged keep-rules (Flutter, flutter_local_
  notifications + Gson, drift/sqlite3, androidx.biometric, native methods) ready
  for when minify is enabled.

`AndroidManifest.xml`:
- `android:label="BudgetSense"` (the user-facing name), `android:icon=
  "@mipmap/ic_launcher"`, `allowBackup="false"`, `fullBackupContent="false"`,
  `dataExtractionRules="@xml/data_extraction_rules"`.
- Activity `.MainActivity` (FlutterFragmentActivity): exported, singleTop, empty
  taskAffinity, LaunchTheme, standard Flutter configChanges,
  windowSoftInputMode=adjustResize. It carries NO launcher intent-filter.
- **A single launcher icon** (`android:icon=@mipmap/ic_launcher`,
  `android:roundIcon=@mipmap/ic_launcher_round`) on `.MainActivity`, which carries
  the MAIN+LAUNCHER intent-filter. No activity-aliases, no alternate icons.
- Eleven widget receivers (Dashboard/QuickAdd/Insights/Balance/Buckets/Rates/
  Runway/NextDue/QuickActions/Glance/NoSpend providers) + the two
  flutter_local_notifications receivers. The NoSpend receiver carries an
  `android:label` so it shows a distinct name in the widget picker.
- Permissions: POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE, USE_BIOMETRIC.
- `queries` for PROCESS_TEXT and https VIEW.
- Debug-only overlay adds INTERNET.

`MainActivity.kt` (`com.budgetsense.budgetsense`): extends
`FlutterFragmentActivity`; `onCreate` sets `FLAG_SECURE` before `super.onCreate`
(secure by default); hosts the widgets `MethodChannel`, the launch-action
plumbing, and a `setScreenSecure` handler that `addFlags`/`clearFlags`
FLAG_SECURE at runtime so the user can opt out of capture protection. It also
hosts the haptics `MethodChannel` (`com.budgetsense.budgetsense/haptics`, method
`haptic`) whose `performHaptic(kind)` drives the `Vibrator` /`VibratorManager`
directly (see Section 6, Haptics).

`res/`:
- `values/styles.xml` Light.NoTitleBar themes; `values-night/styles.xml`
  Black.NoTitleBar themes.
- App icon is the bespoke **ensō** brand mark (a hand-inked brush circle with a
  clay dot on warm cream paper), shipped as committed raster PNGs at each
  required density. `mipmap-anydpi-v26/ic_launcher.xml` +
  `ic_launcher_round.xml`: `<background @color/ic_launcher_background>` (cream
  `#F5EAD1`) + `<foreground @mipmap/ic_launcher_foreground>` (the transparent
  ensō, safe-zoned, 108-432px). Legacy `mipmap-*/ic_launcher.png` (square) and
  `ic_launcher_round.png` (disc) carry the same cream-plus-ensō art for
  pre-API-26. There are no icon vector drawables and no alternate icons.
- `values/colors.xml` (widget light palette + `ic_launcher_background`),
  `values-night/colors.xml` (widget dark palette; `ic_launcher_background` NOT
  overridden so the icon stays cream).
- `xml/data_extraction_rules.xml`, widget layouts and provider-info xml, widget
  shape drawables (see Section 14 and DESIGN.md).

`gradle.properties`: `org.gradle.jvmargs=-Xmx8G ...`, `android.useAndroidX=true`.

---

## 17. iOS Platform Config

`ios/Runner/Info.plist` app-specific keys:
- `NSFaceIDUsageDescription` = "BudgetSense uses Face ID to unlock the app so only
  you can see your finances."
- `CFBundleDisplayName` = "BudgetSense", `CFBundleName` = "BudgetSense".
- `CADisableMinimumFrameDurationOnPhone` = true.
- Standard placeholders (`CFBundleShortVersionString` =
  `$(FLUTTER_BUILD_NAME)`, `CFBundleVersion` = `$(FLUTTER_BUILD_NUMBER)`, etc.).
- No UIBackgroundModes.

The iOS `AppIcon.appiconset` is the opaque ensō art at every required size
(committed raster PNGs at every required size; no alpha, App Store safe).
The app is designed for Android and iOS from one codebase; iOS builds run but the
home-screen widgets and FLAG_SECURE hardening are Android-specific.

---

## 18. Accessibility

- Status is text + icon, never color alone (Section 11, DESIGN.md).
- `MediaQuery.textScaler` clamped to `[0.85, 1.4]` in `app.dart`.
- Reduce motion: settings toggle or OS setting forces `disableAnimations` true and
  theme animation to `Duration.zero`; every micro-animation collapses to zero.
- Semantic labels on interactive elements: CalmCard `onTap` (button), StatTile
  (label: value), CalmProgressBar (value %), nav items (button/selected/label).
- Calm figures: neutral balance and projection with gentle captions instead of
  alarming red.

---

## 19. Testing Requirements

Tests (in `test/`), run with `flutter test`, use `mocktail` and, for DB tests,
`drift/native` `NativeDatabase.memory()`:

- **money_test**: precision, parsing, formatting, arithmetic, divide-by-zero.
- **financial_calendar_test**: month ranges for different start days, keys,
  nextOccurrence.
- **friendly_date_test**: relative naming (Today/Yesterday/Tomorrow), time-of-day
  is ignored, short form omits/includes the year correctly, per-day grouping keys
  never collide, and an uninitialized locale falls back instead of throwing.
- **feedback_widgets_test**: AnimatedMoneyText shows its value with no count-up on
  first build and animates to the new value on change; SuccessCheck fires its
  onCompleted exactly once when the draw finishes.
- **app_fonts_test**: family mapping, handwritten scaling, uniqueness.
- **summary_service_test**: aggregation, investment-treatment modes, archived
  exclusion, rates, and `positiveNote` tiers (half-plus saved, solid share,
  investment-heavy, plain net-positive) plus its silence on negative / no-income
  / break-even months; and the dynamic per-category spend map (`perCategory`),
  which every category breakdown is built from.
- **threshold_service_test**: max/min percentage, fixed amount, and the two
  category-agnostic suggested defaults asserted by exact value (investments
  15% min, unallocated 20% max) - deliberately no category-name references, so
  the suggestions work regardless of which categories the user creates.
- **recurrence_service_test**: complete with/without auto-add, payLoan,
  overdue/upcoming.
- **reminder_planner_test**: scheduling, skip disabled/archived/past, stable ids.
- **reminder_schedule_test**: daily/weekly/monthly occurrence maths (next fire
  after now, weekday walk, month-day clamp to 28, year rollover) and describe().
- **reminder_messages_test**: 100+ messages, all non-empty, emoji-carrying, no em
  dashes / spaced-hyphen dashes, lock-screen length limit.
- **settings_state_test**: haptics + reminder-schedule defaults (haptics on,
  daily 10 PM), toMap/fromMap round-trip, legacy-backup fallbacks, copyWith.
- **haptics_test**: the `Haptics.enabled` gate (no platform call when off; the
  right `HapticFeedback.vibrate` argument when on), via a mocked platform channel.
- **insights_service_test**: trend, average daily spend, projection, MoM change.
- **export_schema_test**: row projection matches headers, scope filtering.
- **snapshot_roundtrip_test**: the complete-snapshot lossless round-trip across
  all three formats (JSON/CSV/XML): every table plus all settings survive
  export+import (unicode, embedded quotes/commas/newlines, null, negatives,
  doubles); format auto-detection; foreign-file (Paisa) rejection; legacy DB-only
  backup import; and forward-compatibility (unknown column + missing future
  column are both safe).
- **trash_backup_roundtrip_test**: archived (trashed) transactions and their
  per-transaction `iconCodePoint` survive backup and restore into a fresh
  database, across all three formats (trash restores as trash).
- **trash_repository_test**: archive moves a row to trash and out of the month
  view; unarchive restores it; emptyTrash permanently clears only archived rows;
  `latestActiveDate` ignores archived rows; `iconCodePoint` round-trips.
- **import_refresh_test**: proves the no-restart-after-import fix. Reproduces the
  stale-stream case (a write that bypasses Drift's per-write notifications, like a
  transaction-wrapped restore) and shows that a freshly built watch, which is
  what `refreshAllDataProviders` creates by invalidating the providers, re-queries
  and surfaces the new row; a one-shot read confirms the data is really present.
- **icon_suggester_test**: keyword auto-detection maps common expenses to the
  right icon, every suggestion resolves to a real `kCategoryIcons` entry, search
  returns in-library matches, and the library exposes 100+ distinct icons.
- **migration_test**: v1 -> v2 upgrade creates all nine indexes (drops then
  recreates to validate real snake_case column names); v2 -> v3 adds the
  `iconCodePoint` column; `schemaVersion == 3`; and onCreate parity.
- **widget_mask_test**: `maskSensitive` hides every financial key, preserves
  metadata, and the sensitive/metadata key sets never overlap.
- **paisa_import_test**: Paisa JSON parsing, type mapping, append-only idempotency.
- **calm_widgets_test**: StatTile, CalmEmptyState, CalmCard, CalmProgressBar,
  glass fallback, every CalmIllustration motif paints without throwing, and
  BrandWatermark shows its child without blocking taps.

Each test verifies behavior (correct output, state changes, edge cases), not
implementation details.

**Continuous integration.** `.github/workflows/ci.yml` runs on every pull request
to `main`: it checks out the repo, installs Flutter 3.44.4 (stable, pinned),
runs `flutter pub get`, regenerates Drift code with
`dart run build_runner build --delete-conflicting-outputs` (the `*.g.dart` files
are gitignored), then `flutter analyze` and the full `flutter test` suite serially
(`--concurrency=1`). Any analyzer issue or failing test fails the PR check. The
gate is exposed via `workflow_call` so other workflows reuse it verbatim.

**Release automation.** `.github/workflows/release.yml` runs on every push to
`main`. It first calls the CI gate above (so a release can never ship code that
would have failed a PR); only if that passes does it: (1) bump the version, patch
+ build number together (`X.Y.Z+N` -> `X.Y.(Z+1)+(N+1)`, which is Android
versionName + a strictly increasing versionCode) in both `pubspec.yaml` and
`app_info.dart`; (2) build the arm64 release APK (signed with the upload key when
the `ANDROID_KEYSTORE_*` secrets are set, otherwise debug-signed via the
`build.gradle.kts` fallback); (3) publish a GitHub Release tagged `vX.Y.Z` with
the APK attached and auto-generated notes; (4) rewrite the README download links
(between the `DOWNLOAD`/`GETTING` marker comments) to point at that release asset;
and (5) commit the bump + README back to `main` with a `[skip ci]` message. The
APK is never committed to git (`dist/` and `*.apk` are gitignored); it lives only
on the Release.

---

## 20. Fonts (bundled, offline)

Declared under `flutter.fonts` in pubspec.yaml, files in `assets/fonts/`:
- ZenMaruGothic (Regular, Medium 500, Bold 700).
- Caveat (Regular), PatrickHand (Regular), GochiHand (Regular),
  ArchitectsDaughter (Regular).
Handwritten faces get `sizeFactor > 1.0` (see DESIGN.md typography).
`assets/branding/budgetsense_mark.png` is the
transparent ensō mark bundled for in-app use (`kBrandMarkAsset`). The composed
logo for the README lives outside the bundle at `docs/budgetsense_logo.png`.

---

## 21. Build and Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerate *.g.dart
flutter create --platforms=android,ios .                    # first time only
flutter run
flutter analyze
flutter test
# Release APK (arm64, obfuscated), as shipped to dist/:
flutter build apk --release --target-platform android-arm64 \
  --obfuscate --split-debug-info=build/symbols
```

`*.g.dart` files (e.g. `app_database.g.dart`) are generated by build_runner and
git-ignored. Regenerate after any Drift schema change (and bump `schemaVersion` +
add an `onUpgrade` step). For a distributable build, add `android/key.properties`
and a keystore (Section 16); without them the release APK is debug-signed.

---

## 22. Key Design Rules and Anti-patterns

1. **Money is never a double.** Store integer minor units; convert only at the UI edge.
2. **Nothing is hard-coded.** Categories, thresholds, currencies live in the DB and are user-editable.
3. **Repository pattern.** UI never touches Drift directly; repositories return domain entities.
4. **Single source of truth.** Dashboard and Insights read the same `monthlySummaryProvider`.
5. **Cloud-ready.** Every record has createdAt/updatedAt/archivedAt/syncStatus.
6. **Accessibility.** Text + icon status, reduce-motion respected, semantic labels everywhere.
7. **Category deletion requires replacement** if transactions reference it.
8. **Notifications are permission-on-demand.** Never requested at startup.
9. **Calm palette.** Muted, earthy, no neon, no aggressive gradients; figures neutral, not red.
10. **Pure domain services.** No Flutter imports, no DB access; trivially unit-testable.
11. **No em-dashes** anywhere in source or user-facing text. No smart/curly quotes or apostrophes.
12. **No ripple effects** (`NoSplash.splashFactory`). Motion is subtle and reduce-motion aware.
13. **Privacy first.** FLAG_SECURE on by default (user-toggleable), backups disabled, widgets masked under lock, no cloud calls, no raw PIN.
14. **No new pub archives.** SDK + hand-authored vectors and CustomPainter art; the one direct-dep addition (`xml`) was already resolved transitively, so nothing new is fetched.
15. **Never assume salary is the only income.** Use IncomeType and semantic buckets, not hard-coded names.
16. **Snapshots must round-trip losslessly and survive schema growth.** Import is tolerant (Section 23); never rely on strict deserialization for user backups.

---

## 23. Complete Snapshot (Export and Import)

A full, format-agnostic, forward-compatible export of EVERYTHING the user owns:
all 11 tables PLUS the entire settings blob (profile, theme, accent, font, app
icon, currency, toggles). Distinct from the transactions spreadsheet (Section 11
Export) and the legacy DB-only backup. This is the durable, user-owned backup.

### Files
- `domain/services/snapshot_service.dart`: `SnapshotFormat { json, csv, xml }`,
  the `AppSnapshot` model (version, exportedAt, appVersion, schemaVersion,
  `settings` map, `tables` map), `SnapshotExport` / `SnapshotImportResult`, the
  `SnapshotService` interface, and `SnapshotException`.
- `data/snapshot/snapshot_tables.dart`: the on-disk table contract: ordered
  `ColSpec` columns per table, `kSnapshotTableOrder` (FK-safe), `readAllTables`
  (export via Drift `toJson`), and `insertSnapshotRows` with TOLERANT companion
  builders.
- `data/snapshot/snapshot_codecs.dart`: `SnapshotCodecs`: `detectFormat`,
  `encode`, `decode` for all three formats.
- `data/snapshot/app_snapshot_service.dart`: `AppSnapshotService` orchestrator.
- Provider: `snapshotServiceProvider` (feature_providers.dart) injects
  `readSettings` (current `SettingsState.toMap()`) and `writeSettings` (full
  replace via `SettingsState.fromMap` through the controller, so theme and icon
  update live).

### Envelope (snapshot version 3)
`{ app: "BudgetSense", snapshot: 3, exportedAt, appVersion, schemaVersion,
settings: {...}, data: { <table>: [ <row>, ... ] } }`. Rows are Drift `toJson`
maps (DateTime serialized as an integer by drift's default serializer).

### Formats
- **JSON**: the canonical, lossless envelope (recommended).
- **CSV (sectioned)**: one file: a `#BUDGETSENSE` marker row, then
  `#SECTION,settings` (a `key,value` table), then a `#SECTION,<table>` block per
  table, each with a header row and data rows. Every cell is a `jsonEncode`d
  scalar, so null, empty-string, number and bool all round-trip; an absent key is
  an empty cell.
- **XML**: `<budgetsense snapshot=..>` with `<settings><s key=..>` and
  `<data><table name=..><row><c key=..>` elements; null is `nil="true"`, otherwise
  the element text is the `jsonEncode`d value.

### Import (auto-detect + restore)
`importBytes(bytes)`:
1. `detectFormat` sniffs leading bytes (`{`/`[` -> JSON, `<` -> XML,
   `#BUDGETSENSE`/`#SECTION` -> CSV).
2. For JSON, it verifies the file is a BudgetSense snapshot (marker `app`, or
   both `settings`+`data`, or a legacy `version`+known-table backup) and REJECTS
   foreign files (e.g. Paisa) with a `SnapshotException` pointing to Settings >
   Import, never a silent misread.
3. Restores all tables in FK order inside one transaction via
   `insertOnConflictUpdate` (upsert by id).
4. Applies settings (via the injected writer) to restore the user's preferences.

### Forward compatibility (survives app updates)
- **Extra keys** in a newer file are ignored; **missing keys** (a column added in
  a later version) become `Value.absent()` so the database default fills them.
  Settings use the defensive `SettingsState.fromMap` (unknown keys dropped,
  missing keys defaulted).
- DateTimes are reconstructed with drift's own default serializer, staying exactly
  symmetric with export regardless of drift's internal storage unit.
- Legacy DB-only backups (v1/v2, no settings) still restore through the JSON path.

### Guarantees (all covered by `snapshot_roundtrip_test`)
Lossless round-trip of every table and every setting across JSON, CSV and XML,
including unicode, embedded quotes/commas/newlines, nulls, negatives and doubles.
