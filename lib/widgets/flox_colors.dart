import 'package:flutter/material.dart';

/// Bright accent colours shared by the Splitwise screens.
class FloxColors {
  FloxColors._();

  static const owed = Color(0xFF2EE59D); // money coming to you
  static const owe = Color(0xFFFF5E7E); // money you owe
  static const neutral = Colors.white54;

  /// Vivid pairs; a friend always gets the same one.
  static const _pairs = [
    [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    [Color(0xFF7C4DFF), Color(0xFFB388FF)],
    [Color(0xFF00C9A7), Color(0xFF4FACFE)],
    [Color(0xFFFF4D9D), Color(0xFFFF9A8B)],
    [Color(0xFFFFB300), Color(0xFFFF7043)],
    [Color(0xFF00B0FF), Color(0xFF00E5FF)],
    [Color(0xFF43E97B), Color(0xFF38F9D7)],
    [Color(0xFFF953C6), Color(0xFFB91D73)],
  ];

  /// Stable per-id hash (String.hashCode can differ between runs).
  static int _hash(String id) => id.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);

  static LinearGradient gradientFor(String id) {
    final pair = _pairs[_hash(id) % _pairs.length];
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: pair);
  }

  static Color colorFor(String id) => _pairs[_hash(id) % _pairs.length].first;

  /// Icon and colour for an expense, guessed from its title.
  static (IconData, Color) categoryFor(String title) {
    final t = title.toLowerCase();
    bool has(List<String> words) => words.any(t.contains);
    if (t.startsWith('settlement')) return (Icons.handshake_rounded, owed);
    if (has([
      'food',
      'dinner',
      'lunch',
      'breakfast',
      'pizza',
      'cafe',
      'coffee',
      'restaurant',
      'zomato',
      'swiggy',
      'snack',
      'tea',
    ])) {
      return (Icons.restaurant_rounded, const Color(0xFFFF8E53));
    }
    if (has([
      'uber',
      'ola',
      'cab',
      'taxi',
      'auto',
      'fuel',
      'petrol',
      'train',
      'bus',
      'flight',
      'metro',
      'travel',
      'trip',
    ])) {
      return (Icons.directions_car_rounded, const Color(0xFF4FACFE));
    }
    if (has(['movie', 'film', 'netflix', 'game', 'party', 'concert', 'ticket'])) {
      return (Icons.local_activity_rounded, const Color(0xFFF953C6));
    }
    if (has(['grocery', 'groceries', 'shop', 'amazon', 'flipkart', 'mart', 'store'])) {
      return (Icons.shopping_bag_rounded, const Color(0xFFFFB300));
    }
    if (has(['rent', 'bill', 'electric', 'wifi', 'internet', 'recharge', 'gas', 'water'])) {
      return (Icons.receipt_long_rounded, const Color(0xFF00E5FF));
    }
    if (has(['hotel', 'stay', 'airbnb', 'room'])) return (Icons.hotel_rounded, const Color(0xFFB388FF));
    return (Icons.receipt_rounded, const Color(0xFF7C4DFF));
  }
}
