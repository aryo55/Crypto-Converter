import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CryptoConverterApp());
}

class CryptoConverterApp extends StatelessWidget {
  const CryptoConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto ke IDR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF0B90B),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
        ),
        cardColor: const Color(0xFF161B22),
      ),
      home: const HomePage(),
    );
  }
}

String formatIdr(double value) {
  final isSmall = value < 100;
  final s = value.toStringAsFixed(isSmall ? 2 : 0);
  final parts = s.split('.');
  final buf = StringBuffer();
  final digits = parts[0];
  for (int i = 0; i < digits.length; i++) {
    buf.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buf.write('.');
  }
  var out = 'Rp ${buf.toString()}';
  if (parts.length > 1) out += ',${parts[1]}';
  return out;
}

String formatIdrShort(double value) {
  if (value >= 1000000000) {
    return 'Rp ${(value / 1000000000).toStringAsFixed(2)} M';
  } else if (value >= 1000000) {
    return 'Rp ${(value / 1000000).toStringAsFixed(2)} jt';
  } else if (value >= 1000) {
    return 'Rp ${(value / 1000).toStringAsFixed(1)} rb';
  }
  return 'Rp ${value.toStringAsFixed(value < 100 ? 2 : 0)}';
}

class Coin {
  final String id;
  final String symbol;
  final String name;
  final String image;
  final double priceIdr;
  final double change24h;

  Coin({
    required this.id,
    required this.symbol,
    required this.name,
    required this.image,
    required this.priceIdr,
    required this.change24h,
  });

  factory Coin.fromJson(Map<String, dynamic> json) {
    return Coin(
      id: json['id'] ?? '',
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      priceIdr: (json['current_price'] ?? 0).toDouble(),
      change24h: (json['price_change_percentage_24h'] ?? 0).toDouble(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Coin> _coins = [];
  List<Coin> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  Set<String> _favorites = {};
  Timer? _autoTimer;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _fetchCoins();
    _searchCtrl.addListener(_applyFilter);
    _autoTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _fetchCoins(silent: true),
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = (prefs.getStringList('favorites') ?? []).toSet();
    });
  }

  Future
