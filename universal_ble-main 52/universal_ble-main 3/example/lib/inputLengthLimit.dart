import 'package:flutter/services.dart';

/// A generic reusable Hex formatter that allows future customization.
class GenericHexFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final newText = newValue.text;
    final formattedText = newText; // Future formatting logic can go here

    int newOffset =
        newValue.selection.baseOffset + (formattedText.length - newText.length);
    newOffset = newOffset.clamp(0, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

/// Returns a list of input formatters for hexadecimal input with max length.
List<TextInputFormatter> buildHexFormatters(
    int maxLength, TextInputFormatter customFormatter) {
  return [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
    LengthLimitingTextInputFormatter(maxLength),
    customFormatter,
  ];
}
