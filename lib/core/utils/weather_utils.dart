import 'package:flutter/material.dart';

IconData weatherIcon(int wmoCode) {
  if (wmoCode == 0 || wmoCode == 1) return Icons.wb_sunny;
  if (wmoCode <= 3) return Icons.cloud;
  if (wmoCode <= 48) return Icons.foggy;
  if (wmoCode <= 67) return Icons.umbrella;
  if (wmoCode <= 77) return Icons.ac_unit;
  if (wmoCode <= 82) return Icons.umbrella;
  if (wmoCode <= 99) return Icons.thunderstorm;
  return Icons.wb_sunny;
}

int weatherIconCodePoint(int wmoCode) => weatherIcon(wmoCode).codePoint;
