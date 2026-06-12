class StringUtilsX {
  static String capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() + value.substring(1);
  }

  static const String _diacritics =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  static const String _plain =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  /// Lowercases and strips Vietnamese diacritics so user-entered or
  /// OCR-extracted text can be compared loosely ("Massage Toàn Thân"
  /// matches "massage toan than").
  static String normalizeForSearch(String value) {
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = _diacritics.indexOf(char);
      buffer.write(index == -1 ? char : _plain[index]);
    }
    return buffer.toString().trim();
  }

  const StringUtilsX._();
}
