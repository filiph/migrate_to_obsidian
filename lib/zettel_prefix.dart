String createZettelPrefix(DateTime date) =>
    date.toIso8601String().substring(0, 10);
