class FlagEmoji {
  const FlagEmoji._();

  static String fromIsoA2(
    String isoA2,
  ) {
    final String normalizedCode =
        isoA2.trim().toUpperCase();

    if (!RegExp(r'^[A-Z]{2}$')
        .hasMatch(normalizedCode)) {
      return '🏳️';
    }

    final int firstRegionalIndicator =
        0x1F1E6 +
            normalizedCode.codeUnitAt(0) -
            65;

    final int secondRegionalIndicator =
        0x1F1E6 +
            normalizedCode.codeUnitAt(1) -
            65;

    return String.fromCharCodes(
      <int>[
        firstRegionalIndicator,
        secondRegionalIndicator,
      ],
    );
  }
}