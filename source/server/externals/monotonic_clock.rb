class MonotonicClock
  # Seconds, as a Float, from a clock that only ever goes forwards. Its origin
  # is the machine booting rather than 1970, so a reading means nothing on its
  # own and everything when subtracted from another.
  #
  # The wall clock would not do. ntp steps it, and so does a daylight-saving
  # change, either of which can move it backwards. An age measured across that
  # comes out shorter than it really is, or negative, and whatever the age was
  # guarding then lets through the very thing it was there to catch.
  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
