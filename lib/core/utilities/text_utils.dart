/// Utility for handling text layouts.
class TextUtils {
  /// Splits a string into at most two lines, attempting to wrap at a space 
  /// before the [limit] characters. If no space is found, it hard-splits at the limit.
  static List<String> splitToTwoLines(String text, {int limit = 16, int? limitLine2}) {
    final secondLimit = limitLine2 ?? limit;
    if (text.length <= limit) {
      return [text];
    }
    
    final firstPart = text.substring(0, limit);
    final lastSpaceIndex = firstPart.lastIndexOf(' ');
    
    String line1;
    String line2;

    if (lastSpaceIndex > 0) {
      line1 = text.substring(0, lastSpaceIndex).trim();
      line2 = text.substring(lastSpaceIndex).trim();
    } else {
      line1 = text.substring(0, limit);
      line2 = text.substring(limit).trim();
    }

    if (line2.length > secondLimit) {
      line2 = line2.substring(0, secondLimit);
    }
    
    return [line1, line2];
  }
}
