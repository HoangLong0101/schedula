class StringUtilsX {
  static String capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() + value.substring(1);
  }

  const StringUtilsX._();
}