/// Writes [time] as a clock does, in whole seconds: `0:07`, `4:12` or
/// `1:02:03`.
String formatPlayTime(Duration time) {
  final hours = time.inHours;
  final minutes = time.inMinutes.remainder(Duration.minutesPerHour);
  final seconds = time.inSeconds.remainder(Duration.secondsPerMinute);
  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours == 0) {
    return '$minutes:$paddedSeconds';
  }
  return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
}

/// Describes [time] in words for screen readers, in whole seconds, such as
/// `4 minutes 12 seconds` or `1 hour 3 seconds`.
String describePlayTime(Duration time) {
  final parts = [
    (time.inHours, 'hour'),
    (time.inMinutes.remainder(Duration.minutesPerHour), 'minute'),
    (time.inSeconds.remainder(Duration.secondsPerMinute), 'second'),
  ];
  final words = [
    for (final (count, unit) in parts)
      if (count > 0) '$count $unit${count == 1 ? '' : 's'}',
  ];
  return words.isEmpty ? '0 seconds' : words.join(' ');
}
