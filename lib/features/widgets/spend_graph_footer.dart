/// Rotating footer lines for the spend-activity ("No-spend days") home widget.
///
/// The widget footer used to read a flat "No-spend days". Instead it now shows a
/// gently motivating line that changes each day. There are two pools: one that
/// weaves in the person's name (from onboarding) and one that stands on its own.
/// [spendFooterMessage] picks deterministically from the day, so it is stable
/// across a day and unit-testable, and it never uses an em dash.
///
/// Keep both pools long (100+ lines combined) so the footer stays fresh.
library;

/// Lines that address the user by name. `{name}` is substituted at render time.
const List<String> kFooterLinesWithName = [
  "Nice and steady, {name}.",
  "You've got this, {name}.",
  "One mindful day at a time, {name}.",
  "Small wins add up, {name}.",
  "Proud of you, {name}.",
  "Keep it calm, {name}.",
  "Every rupee noticed, {name}.",
  "Look at that rhythm, {name}.",
  "Money with intention, {name}.",
  "{name}, your future self says thanks.",
  "Gentle progress, {name}.",
  "{name}, calm beats perfect.",
  "A quiet, careful month, {name}.",
  "{name}, you're building a habit.",
  "Slow money is happy money, {name}.",
  "{name}, breathe and spend on purpose.",
  "Right on track, {name}.",
  "{name}, every note counts.",
  "Kind to your wallet, {name}.",
  "{name}, one square at a time.",
  "Steady hands, {name}.",
  "{name}, that's real discipline.",
  "Mindful, not restrictive, {name}.",
  "{name}, your patience is paying off.",
  "Keep the streak alive, {name}.",
  "{name}, less noise, more clarity.",
  "You're doing the quiet work, {name}.",
  "{name}, tiny choices, big peace.",
  "A calmer wallet, {name}.",
  "{name}, spending with eyes open.",
  "Well tracked, {name}.",
  "{name}, momentum looks good on you.",
  "Steady as she goes, {name}.",
  "{name}, you noticed, that's everything.",
  "Grace over guilt, {name}.",
  "{name}, keep planting good days.",
  "Quiet confidence, {name}.",
  "{name}, your money knows where it's going.",
  "Softly does it, {name}.",
  "{name}, another honest day logged.",
  "Balance, not perfection, {name}.",
  "{name}, you're the calm in the numbers.",
  "One good habit, repeated, {name}.",
  "{name}, this is what steady feels like.",
  "Bit by bit, {name}.",
  "{name}, you make it look easy.",
  "Careful and kind, {name}.",
  "{name}, keep the good days coming.",
  "Present and paying attention, {name}.",
  "{name}, gentle wins the race.",
  "Every day, a little wiser, {name}.",
  "{name}, calm money, clear mind.",
  "Keep showing up, {name}.",
  "{name}, your budget is breathing easy.",
  "Mindful spending suits you, {name}.",
];

/// Lines that stand alone (used when no name was given during onboarding).
const List<String> kFooterLinesPlain = [
  "Nice and steady.",
  "One mindful day at a time.",
  "Small wins add up.",
  "Money with intention.",
  "Your future self says thanks.",
  "Gentle progress beats perfect.",
  "Every rupee noticed.",
  "Calm beats perfect.",
  "A quiet, careful month.",
  "You're building a habit.",
  "Slow money is happy money.",
  "Breathe and spend on purpose.",
  "Right on track.",
  "Every note counts.",
  "Kind to your wallet.",
  "One square at a time.",
  "Steady hands.",
  "That's real discipline.",
  "Mindful, not restrictive.",
  "Patience is paying off.",
  "Keep the streak alive.",
  "Less noise, more clarity.",
  "Doing the quiet work.",
  "Tiny choices, big peace.",
  "A calmer wallet.",
  "Spending with eyes open.",
  "Well tracked.",
  "Momentum is on your side.",
  "Steady as she goes.",
  "Noticing is everything.",
  "Grace over guilt.",
  "Keep planting good days.",
  "Quiet confidence.",
  "Your money knows where it's going.",
  "Softly does it.",
  "Another honest day logged.",
  "Balance, not perfection.",
  "Be the calm in the numbers.",
  "One good habit, repeated.",
  "This is what steady feels like.",
  "Bit by bit.",
  "Careful and kind.",
  "Keep the good days coming.",
  "Present and paying attention.",
  "Gentle wins the race.",
  "Every day, a little wiser.",
  "Calm money, clear mind.",
  "Keep showing up.",
  "Your budget is breathing easy.",
  "Mindful spending looks good.",
  "Progress, not pressure.",
  "A little awareness goes far.",
  "Spend slow, live easy.",
  "Small and steady wins.",
  "Today counted. Well done.",
];

/// Picks a footer line for [day], weaving in [name] when it is non-empty.
///
/// Deterministic (same day gives the same line) so it is stable and testable.
/// Chooses from the name pool when a name exists, otherwise the plain pool.
/// Returns a single line with no em dashes and the `{name}` token resolved.
String spendFooterMessage(String? name, DateTime day) {
  final trimmed = name?.trim() ?? '';
  final hasName = trimmed.isNotEmpty;
  final pool = hasName ? kFooterLinesWithName : kFooterLinesPlain;
  // Day-of-year index keeps it stable per day and cycles through the pool.
  final dayOfYear = day.difference(DateTime(day.year)).inDays; // 0..365
  final line = pool[dayOfYear % pool.length];
  return hasName ? line.replaceAll('{name}', trimmed) : line;
}
