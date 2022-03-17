import 'package:diacritic/diacritic.dart';

String convertToAsciiName(String title) => removeDiacritics(title)
    .replaceAll(RegExp(r'[\:\/\\]'), "-")
    .replaceAll(RegExp(r'''["\.\!\*\?#<>]'''), "")
    .replaceAll("[", "(")
    .replaceAll("]", ")")
    .trim()
    .split(RegExp(r'\s'))
    .take(10)
    .join(' ');