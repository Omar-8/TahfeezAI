/// Time-of-day greeting bands, kept as a small pure enum + function so the
/// hour→greeting mapping is unit-testable without needing a widget tree or
/// a fixed clock.
enum HomeGreetingBand { morning, afternoon, evening }

HomeGreetingBand homeGreetingBandForHour(int hour) {
  if (hour < 12) return HomeGreetingBand.morning;
  if (hour < 18) return HomeGreetingBand.afternoon;
  return HomeGreetingBand.evening;
}
