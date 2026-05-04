/// Dart Extensions
extension StringExtension on String {
  String capitalize() {
    return length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : '';
  }
  
  bool isValidEmail() {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(this);
  }
}

extension DateTimeExtension on DateTime {
  String toFormattedString() {
    return '$year-$month-$day';
  }
}
