/// Domain-wide enumerations. Kept in one place so nothing gets hard-coded
/// as loose strings across the codebase.
library;

/// The kind of money movement a transaction represents.
enum TransactionType {
  expense,
  income,
  investment,
  loanPayment,
  recurringPayment,
  custom,
}

extension TransactionTypeX on TransactionType {
  String get label => switch (this) {
        TransactionType.expense => 'Expense',
        TransactionType.income => 'Income',
        TransactionType.investment => 'Investment',
        TransactionType.loanPayment => 'Loan payment',
        TransactionType.recurringPayment => 'Recurring payment',
        TransactionType.custom => 'Custom',
      };

  /// Whether this type reduces available balance (an outflow).
  bool get isOutflow => this != TransactionType.income;
}

/// How a recurring payment / investment repeats.
enum Frequency {
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  halfYearly,
  yearly,
  custom,
}

extension FrequencyX on Frequency {
  String get label => switch (this) {
        Frequency.daily => 'Daily',
        Frequency.weekly => 'Weekly',
        Frequency.biweekly => 'Biweekly',
        Frequency.monthly => 'Monthly',
        Frequency.quarterly => 'Quarterly',
        Frequency.halfYearly => 'Half-yearly',
        Frequency.yearly => 'Yearly',
        Frequency.custom => 'Custom interval',
      };
}

/// Categories of recurring / scheduled commitments.
enum PaymentKind {
  sip,
  mutualFund,
  recurringDeposit,
  fixedDeposit,
  insurancePremium,
  subscription,
  rent,
  loanEmi,
  creditCard,
  utility,
  customInvestment,
  customRecurring,
}

extension PaymentKindX on PaymentKind {
  String get label => switch (this) {
        PaymentKind.sip => 'SIP',
        PaymentKind.mutualFund => 'Mutual fund',
        PaymentKind.recurringDeposit => 'Recurring deposit',
        PaymentKind.fixedDeposit => 'Fixed deposit',
        PaymentKind.insurancePremium => 'Insurance premium',
        PaymentKind.subscription => 'Subscription',
        PaymentKind.rent => 'Rent',
        PaymentKind.loanEmi => 'Loan EMI',
        PaymentKind.creditCard => 'Credit card',
        PaymentKind.utility => 'Utility bill',
        PaymentKind.customInvestment => 'Custom investment',
        PaymentKind.customRecurring => 'Custom recurring',
      };

  bool get isInvestment =>
      this == PaymentKind.sip ||
      this == PaymentKind.mutualFund ||
      this == PaymentKind.recurringDeposit ||
      this == PaymentKind.fixedDeposit ||
      this == PaymentKind.customInvestment;
}

/// Kinds of income a user can record. Never assume salary is the only source.
enum IncomeType {
  salary,
  bonus,
  interest,
  refund,
  reimbursement,
  freelance,
  investmentReturns,
  other,
}

extension IncomeTypeX on IncomeType {
  String get label => switch (this) {
        IncomeType.salary => 'Salary',
        IncomeType.bonus => 'Bonus',
        IncomeType.interest => 'Interest income',
        IncomeType.refund => 'Refund',
        IncomeType.reimbursement => 'Reimbursement',
        IncomeType.freelance => 'Freelance',
        IncomeType.investmentReturns => 'Investment returns',
        IncomeType.other => 'Other',
      };
}

/// Custom field data types (Section 6 of the spec).
enum CustomFieldType {
  text,
  number,
  currency,
  percentage,
  date,
  time,
  toggle,
  dropdown,
  multiSelect,
  notes,
}

extension CustomFieldTypeX on CustomFieldType {
  String get label => switch (this) {
        CustomFieldType.text => 'Text',
        CustomFieldType.number => 'Number',
        CustomFieldType.currency => 'Currency',
        CustomFieldType.percentage => 'Percentage',
        CustomFieldType.date => 'Date',
        CustomFieldType.time => 'Time',
        CustomFieldType.toggle => 'Toggle',
        CustomFieldType.dropdown => 'Dropdown',
        CustomFieldType.multiSelect => 'Multi-select',
        CustomFieldType.notes => 'Notes',
      };
}

/// How a threshold is measured.
enum ThresholdType {
  maxPercentage,
  minPercentage,
  maxAmount,
  minAmount,
}

extension ThresholdTypeX on ThresholdType {
  bool get isPercentage =>
      this == ThresholdType.maxPercentage ||
      this == ThresholdType.minPercentage;
  bool get isMax =>
      this == ThresholdType.maxPercentage || this == ThresholdType.maxAmount;
}

/// The resolved state of a threshold after evaluation. Communicated with
/// icons + text as well as color, never color alone (accessibility).
enum ThresholdStatus {
  safe,
  approaching,
  exceeded,
  belowTarget,
  targetAchieved,
}

extension ThresholdStatusX on ThresholdStatus {
  String get label => switch (this) {
        ThresholdStatus.safe => 'Safe',
        ThresholdStatus.approaching => 'Approaching limit',
        ThresholdStatus.exceeded => 'Exceeded',
        ThresholdStatus.belowTarget => 'Below target',
        ThresholdStatus.targetAchieved => 'Target achieved',
      };
}

/// How investments should be treated in the monthly balance formula.
enum InvestmentTreatment { spending, savings, separate }

/// How often the "record your expenses" reminder repeats. Distinct from
/// [Frequency] (which is for financial commitments) so the two never get
/// tangled together.
enum ReminderFrequency { daily, weekly, monthly }

extension ReminderFrequencyX on ReminderFrequency {
  String get label => switch (this) {
        ReminderFrequency.daily => 'Every day',
        ReminderFrequency.weekly => 'Every week',
        ReminderFrequency.monthly => 'Every month',
      };
}

/// Placeholder for future cloud sync. Every record carries one.
enum SyncStatus { localOnly, pendingUpload, synced, conflict }
