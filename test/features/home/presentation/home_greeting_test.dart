import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/home/presentation/home_greeting.dart';

void main() {
  test('hour-to-greeting-band mapping covers a full day with no gaps', () {
    expect(homeGreetingBandForHour(0), HomeGreetingBand.morning);
    expect(homeGreetingBandForHour(6), HomeGreetingBand.morning);
    expect(homeGreetingBandForHour(11), HomeGreetingBand.morning);
    expect(homeGreetingBandForHour(12), HomeGreetingBand.afternoon);
    expect(homeGreetingBandForHour(17), HomeGreetingBand.afternoon);
    expect(homeGreetingBandForHour(18), HomeGreetingBand.evening);
    expect(homeGreetingBandForHour(23), HomeGreetingBand.evening);
  });
}
