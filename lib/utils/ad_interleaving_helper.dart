/// Helper for interleaving inline ads into list and grid presentations.
///
/// Ensures virtual list mapping is strictly confined to the UI layer and
/// never mutates underlying database collections or Drift streams.
class AdInterleavingHelper {
  AdInterleavingHelper._();

  /// Default frequency interval for inline ads (every 5 data items).
  static const int defaultAdInterval = 5;

  /// Checks if a given [visualIndex] corresponds to an interleaved ad slot.
  ///
  /// For interval = 5:
  /// Visual indices 0..4 -> data items 0..4
  /// Visual index 5     -> Ad slot 1
  /// Visual indices 6..10-> data items 5..9
  /// Visual index 11    -> Ad slot 2
  static bool isAdIndex(int visualIndex, {int interval = defaultAdInterval}) {
    return (visualIndex + 1) % (interval + 1) == 0;
  }

  /// Returns the total visual count (data items plus interleaved ads).
  static int getVisualCount(int dataCount, bool showAds, {int interval = defaultAdInterval}) {
    if (!showAds || dataCount == 0) return dataCount;
    final int adCount = dataCount ~/ interval;
    return dataCount + adCount;
  }

  /// Maps a [visualIndex] back to the actual zero-based data index in the list.
  static int getDataIndex(int visualIndex, {int interval = defaultAdInterval}) {
    return visualIndex - (visualIndex ~/ (interval + 1));
  }
}
