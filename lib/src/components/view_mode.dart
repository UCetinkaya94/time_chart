enum ViewMode {
  weekly(7),
  monthly(31),
  yearly(12);

  const ViewMode(this.dayCount);

  /// The count of blocks in the x-axis direction.
  final int dayCount;
}

class DateDuration {
  final DateTime date;
  final Duration duration;

  DateDuration(this.date, this.duration);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DateDuration &&
        other.date == date &&
        other.duration == duration;
  }

  @override
  int get hashCode => date.hashCode ^ duration.hashCode;
}
