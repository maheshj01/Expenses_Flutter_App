/// Injectable source of "now" so time-dependent logic stays testable.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();
