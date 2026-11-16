/// Parses the quantity at the start of an ingredient line and scales it.
///
/// Handles: "2", "1.5", "1/2", "1 1/2", "1-1/2", "½", "1½", ranges like
/// "2-3" / "2 to 3" / "2–3", and numbers glued to units ("200g").
class IngredientScaler {
  static const _unicodeFractions = {
    '½': 0.5, '⅓': 1 / 3, '⅔': 2 / 3, '¼': 0.25, '¾': 0.75, '⅕': 0.2,
    '⅖': 0.4, '⅗': 0.6, '⅘': 0.8, '⅙': 1 / 6, '⅚': 5 / 6, '⅛': 0.125,
    '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
  };

  static final String _uf = _unicodeFractions.keys.join();

  // A single amount: mixed number, fraction, decimal, integer, unicode fraction.
  static final String _amount =
      r'(?:\d+\s*[' + _uf + r']|\d+(?:\s+|-)\d+\s*/\s*\d+|\d+\s*/\s*\d+|\d*\.\d+|\d+|[' + _uf + r'])';

  static final RegExp _lead = RegExp(
    r'^(\s*[-•*]?\s*)(' + _amount + r')(?:(\s*(?:-|–|—|to|or)\s*)(' + _amount + r'))?',
    caseSensitive: false,
  );

  /// Parses an amount string to a double, or null.
  static double? parseAmount(String s) {
    s = s.trim();
    if (s.isEmpty) return null;
    // unicode fraction, possibly preceded by whole number
    for (final e in _unicodeFractions.entries) {
      if (s.endsWith(e.key)) {
        final whole = s.substring(0, s.length - e.key.length).trim();
        return (whole.isEmpty ? 0 : (double.tryParse(whole) ?? 0)) + e.value;
      }
    }
    final mixed = RegExp(r'^(\d+)(?:\s+|-)(\d+)\s*/\s*(\d+)$').firstMatch(s);
    if (mixed != null) {
      final d = int.parse(mixed[3]!);
      if (d == 0) return null;
      return int.parse(mixed[1]!) + int.parse(mixed[2]!) / d;
    }
    final frac = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(s);
    if (frac != null) {
      final d = int.parse(frac[2]!);
      if (d == 0) return null;
      return int.parse(frac[1]!) / d;
    }
    return double.tryParse(s);
  }

  /// Formats a number nicely: cooking fractions for small values, rounded numbers otherwise.
  static String format(double v, {bool preferDecimal = false}) {
    if (v <= 0) return '0';
    if (preferDecimal || v >= 20) {
      if (v >= 100) return v.round().toString();
      final r = (v * 10).round() / 10;
      return r == r.roundToDouble() ? r.round().toString() : r.toString();
    }
    const denoms = [2, 3, 4, 8];
    final whole = v.floor();
    final frac = v - whole;
    if (frac < 0.04) return '$whole';
    if (frac > 0.96) return '${whole + 1}';
    String? best;
    double bestErr = 1;
    for (final d in denoms) {
      final n = (frac * d).round();
      if (n == 0 || n == d) continue;
      final err = (frac - n / d).abs();
      if (err < bestErr - 1e-9) {
        bestErr = err;
        final g = _gcd(n, d);
        best = '${n ~/ g}/${d ~/ g}';
      }
    }
    if (best == null || bestErr > 0.04) {
      final r = (v * 100).round() / 100;
      return r.toString();
    }
    return whole == 0 ? best : '$whole $best';
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  /// Returns the ingredient line with its leading quantity multiplied by [factor].
  static String scaleLine(String line, double factor) {
    if (factor == 1 || line.startsWith('#')) return line;
    final m = _lead.firstMatch(line);
    if (m == null) return line;
    final a = parseAmount(m[2]!);
    if (a == null) return line;
    final preferDecimal = m[2]!.contains('.');
    final buf = StringBuffer(m[1]!)..write(format(a * factor, preferDecimal: preferDecimal));
    if (m[4] != null) {
      final b = parseAmount(m[4]!);
      if (b != null) {
        buf
          ..write(m[3]!)
          ..write(format(b * factor, preferDecimal: preferDecimal));
      } else {
        buf..write(m[3]!)..write(m[4]!);
      }
    }
    var rest = line.substring(m.end);
    // Scale a metric/imperial equivalent in parentheses right after the unit,
    // e.g. "32 fl oz (1 L) water", but not package sizes like "1 (14 oz) can".
    final eq = RegExp(r'^(\s*[A-Za-z][A-Za-z. ]{0,14}?\s*\()(' + _amount + r')(\s*[A-Za-zµ°]+\.?\))').firstMatch(rest);
    if (eq != null) {
      final v = parseAmount(eq[2]!);
      if (v != null) {
        rest = '${eq[1]}${format(v * factor, preferDecimal: eq[2]!.contains('.'))}${eq[3]}${rest.substring(eq.end)}';
      }
    }
    buf.write(rest);
    return buf.toString();
  }

  /// Replaces Unicode vulgar fractions with plain "1/2" style text.
  static String asciiFractions(String s) {
    const map = {
      '½': '1/2', '⅓': '1/3', '⅔': '2/3', '¼': '1/4', '¾': '3/4', '⅕': '1/5', '⅖': '2/5', '⅗': '3/5',
      '⅘': '4/5', '⅙': '1/6', '⅚': '5/6', '⅛': '1/8', '⅜': '3/8', '⅝': '5/8', '⅞': '7/8',
    };
    return s.replaceAllMapped(RegExp('(\\d?)([${map.keys.join()}])'),
        (m) => '${m[1]!.isEmpty ? '' : '${m[1]} '}${map[m[2]]}');
  }

  /// Splits a line into (quantity, rest) for display, e.g. "1 1/2 cups flour" -> ("1 1/2", " cups flour").
  static (String, String) splitQuantity(String line) {
    final m = _lead.firstMatch(line);
    if (m == null) return ('', line);
    return (line.substring(0, m.end).trim(), line.substring(m.end));
  }
}
