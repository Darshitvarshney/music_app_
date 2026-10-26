/// Time-of-day periods used for the home screen greeting (device local time).
enum GreetingPeriod {
  /// 00:00 - 03:59
  lateNight,

  /// 04:00 - 05:59
  earlyMorning,

  /// 06:00 - 11:59
  morning,

  /// 12:00 - 16:59
  afternoon,

  /// 17:00 - 20:59
  evening,

  /// 21:00 - 23:59
  night,
}

const Map<GreetingPeriod, List<String>> _phrases = {
  GreetingPeriod.lateNight: [
    'Night owl mode on',
    'Still up? Music awaits',
    'Burning the midnight oil',
    'Late night vibes',
  ],
  GreetingPeriod.earlyMorning: [
    'Up before the sun',
    'Early bird, early beats',
    'Quiet hours, loud tunes',
  ],
  GreetingPeriod.morning: [
    'Good morning',
    'Rise and shine',
    'Start the day right',
    'Fresh morning, fresh beats',
  ],
  GreetingPeriod.afternoon: [
    'Good afternoon',
    'Afternoon groove',
    'Keep the energy up',
    'Your midday soundtrack',
  ],
  GreetingPeriod.evening: [
    'Good evening',
    'Golden hour tunes',
    'Time to unwind',
    'Wind down with music',
  ],
  GreetingPeriod.night: [
    'Night mode on',
    'Time to wind down',
    'Late evening listening',
    'Good night vibes',
  ],
};

/// Which period a local [hour] (0-23) falls in.
GreetingPeriod greetingPeriodForHour(int hour) {
  if (hour < 4) return GreetingPeriod.lateNight;
  if (hour < 6) return GreetingPeriod.earlyMorning;
  if (hour < 12) return GreetingPeriod.morning;
  if (hour < 17) return GreetingPeriod.afternoon;
  if (hour < 21) return GreetingPeriod.evening;
  return GreetingPeriod.night;
}

/// All phrases that can be shown for [period].
List<String> greetingPhrasesFor(GreetingPeriod period) =>
    List.unmodifiable(_phrases[period]!);

/// Greeting for [now]. Picked from the date and hour (not random), so it only
/// changes hourly.
String greetingForTime(DateTime now) {
  final phrases = _phrases[greetingPeriodForHour(now.hour)]!;
  // Whole days since 2000-01-01 (UTC math on the calendar date, so DST can't skew it).
  final days = DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(2000))
      .inDays;
  final slot = days * 5 + now.hour;
  return phrases[slot % phrases.length];
}
