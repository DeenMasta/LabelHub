abstract final class LabelUnits {
  static const double millimetresPerInch = 25.4;

  static double mmToPoints(double millimetres) =>
      millimetres / millimetresPerInch * 72;

  static int mmToDots(double millimetres, int dpi) =>
      (millimetres / millimetresPerInch * dpi).round();
}
