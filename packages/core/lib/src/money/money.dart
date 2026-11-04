import 'package:flutter/foundation.dart';

@immutable
class Money implements Comparable<Money> {
  const Money.fromCents(this.cents);

  final int cents;

  static const Money zero = Money.fromCents(0);

  static const int maxCents = 100000000;

  bool get isZero => cents == 0;
  bool get isNegative => cents < 0;

  Money operator +(Money other) => Money.fromCents(cents + other.cents);
  Money operator -(Money other) => Money.fromCents(cents - other.cents);
  Money operator *(int quantity) => Money.fromCents(cents * quantity);

  String format({String symbol = '£'}) {
    final negative = cents < 0;
    final absolute = cents.abs();
    final major = absolute ~/ 100;
    final minor = absolute % 100;
    final buffer = StringBuffer()
      ..write(negative ? '-' : '')
      ..write(symbol)
      ..write(_group(major))
      ..write('.')
      ..write(minor.toString().padLeft(2, '0'));
    return buffer.toString();
  }

  static String _group(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      if (i > 0 && remaining % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String toEditingString() {
    final negative = cents < 0;
    final absolute = cents.abs();
    return '${negative ? '-' : ''}${absolute ~/ 100}.'
        '${(absolute % 100).toString().padLeft(2, '0')}';
  }

  static Money? tryParse(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;

    text = text.replaceFirstMapped(
      RegExp(r'^(-?)[£$€]\s*'),
      (match) => match.group(1)!,
    );
    final normalised = _normaliseSeparators(text);
    if (normalised == null) return null;
    text = normalised;

    final match = RegExp(r'^(-?)(\d*)(?:\.(\d{0,2}))?$').firstMatch(text);
    if (match == null) return null;

    final sign = match.group(1) == '-' ? -1 : 1;
    final majorText = match.group(2) ?? '';
    final minorText = match.group(3);
    if (majorText.isEmpty && (minorText == null || minorText.isEmpty)) {
      return null;
    }

    final major = majorText.isEmpty ? 0 : int.tryParse(majorText);
    if (major == null) return null;
    final minor = minorText == null || minorText.isEmpty
        ? 0
        : int.parse(minorText.padRight(2, '0'));

    if (major > maxCents ~/ 100) return null;
    final total = sign * (major * 100 + minor);
    if (total.abs() > maxCents) return null;
    return Money.fromCents(total);
  }

  static String? _normaliseSeparators(String input) {
    final text = input;
    final lastComma = text.lastIndexOf(',');
    final lastDot = text.lastIndexOf('.');

    if (lastComma >= 0 && lastDot >= 0) {
      final decimalAt = lastComma > lastDot ? lastComma : lastDot;
      final decimal = text[decimalAt];
      final grouping = decimal == ',' ? '.' : ',';
      final whole = text.substring(0, decimalAt);
      if (whole.contains(decimal) || !_isGrouped(whole, grouping)) return null;
      return '${whole.replaceAll(grouping, '')}.${text.substring(decimalAt + 1)}';
    }

    if (lastComma >= 0) {
      final trailing = text.length - lastComma - 1;
      final isGrouping = trailing == 3 && lastComma > 0;
      if (isGrouping) {
        return _isGrouped(text, ',') ? text.replaceAll(',', '') : null;
      }
      if (text.indexOf(',') != lastComma) return null;
      return text.replaceAll(',', '.');
    }

    return text;
  }

  static bool _isGrouped(String whole, String separator) {
    if (!whole.contains(separator)) return true;
    final digits = whole.startsWith('-') ? whole.substring(1) : whole;
    final groups = digits.split(separator);
    return groups.first.isNotEmpty &&
        !groups.first.startsWith('0') &&
        groups.first.length <= 3 &&
        groups.skip(1).every((group) => group.length == 3) &&
        groups.every((group) => RegExp(r'^\d+$').hasMatch(group));
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'Money(${format()})';
}
