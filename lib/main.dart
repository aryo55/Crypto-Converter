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
      title: 'Crypto Converter',
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

// ---------------------------------------------------------------------------
// Currency metadata (world currencies, used to convert from USD/USDT rates
// returned by the forex API into whatever the user picks).
// ---------------------------------------------------------------------------

const Map<String, String> currencySymbols = {
  'USD': '\$', 'IDR': 'Rp', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'CNY': '¥',
  'KRW': '₩', 'INR': '₹', 'SGD': 'S\$', 'MYR': 'RM', 'THB': '฿', 'AUD': 'A\$',
  'CAD': 'C\$', 'CHF': 'CHF', 'HKD': 'HK\$', 'PHP': '₱', 'VND': '₫',
  'RUB': '₽', 'BRL': 'R\$', 'MXN': 'MX\$', 'ZAR': 'R', 'AED': 'د.إ',
  'SAR': '﷼', 'TRY': '₺', 'NGN': '₦', 'PKR': '₨', 'BDT': '৳', 'EGP': 'E£',
  'ARS': 'AR\$', 'CLP': 'CL\$', 'COP': 'CO\$', 'PLN': 'zł', 'SEK': 'kr',
  'NOK': 'kr', 'DKK': 'kr', 'CZK': 'Kč', 'HUF': 'Ft', 'ILS': '₪',
  'QAR': 'ر.ق', 'KWD': 'د.ك', 'BHD': '.د.ب', 'OMR': 'ر.ع.', 'JOD': 'د.ا',
  'LKR': 'Rs', 'NPR': 'Rs', 'MMK': 'K', 'KHR': '៛', 'LAK': '₭',
  'BND': 'B\$', 'TWD': 'NT\$', 'UAH': '₴', 'KZT': '₸', 'GEL': '₾',
  'NZD': 'NZ\$', 'PGK': 'K', 'FJD': 'FJ\$', 'MAD': 'د.م.', 'KES': 'KSh',
  'GHS': 'GH₵', 'TZS': 'TSh',
};

const Map<String, String> currencyNames = {
  'USD': 'US Dollar', 'IDR': 'Indonesian Rupiah', 'EUR': 'Euro',
  'GBP': 'British Pound', 'JPY': 'Japanese Yen', 'CNY': 'Chinese Yuan',
  'KRW': 'South Korean Won', 'INR': 'Indian Rupee', 'SGD': 'Singapore Dollar',
  'MYR': 'Malaysian Ringgit', 'THB': 'Thai Baht', 'AUD': 'Australian Dollar',
  'CAD': 'Canadian Dollar', 'CHF': 'Swiss Franc', 'HKD': 'Hong Kong Dollar',
  'PHP': 'Philippine Peso', 'VND': 'Vietnamese Dong', 'RUB': 'Russian Ruble',
  'BRL': 'Brazilian Real', 'MXN': 'Mexican Peso', 'ZAR': 'South African Rand',
  'AED': 'UAE Dirham', 'SAR': 'Saudi Riyal', 'TRY': 'Turkish Lira',
  'NGN': 'Nigerian Naira', 'PKR': 'Pakistani Rupee', 'BDT': 'Bangladeshi Taka',
  'EGP': 'Egyptian Pound', 'ARS': 'Argentine Peso', 'CLP': 'Chilean Peso',
  'COP': 'Colombian Peso', 'PLN': 'Polish Zloty', 'SEK': 'Swedish Krona',
  'NOK': 'Norwegian Krone', 'DKK': 'Danish Krone', 'CZK': 'Czech Koruna',
  'HUF': 'Hungarian Forint', 'ILS': 'Israeli Shekel', 'QAR': 'Qatari Riyal',
  'KWD': 'Kuwaiti Dinar', 'BHD': 'Bahraini Dinar', 'OMR': 'Omani Rial',
  'JOD': 'Jordanian Dinar', 'LKR': 'Sri Lankan Rupee', 'NPR': 'Nepalese Rupee',
  'MMK': 'Myanmar Kyat', 'KHR': 'Cambodian Riel', 'LAK': 'Lao Kip',
  'BND': 'Brunei Dollar', 'TWD': 'Taiwan Dollar', 'UAH': 'Ukrainian Hryvnia',
  'KZT': 'Kazakhstani Tenge', 'GEL': 'Georgian Lari',
  'NZD': 'New Zealand Dollar', 'PGK': 'Papua New Guinean Kina',
  'FJD': 'Fijian Dollar', 'MAD': 'Moroccan Dirham', 'KES': 'Kenyan Shilling',
  'GHS': 'Ghanaian Cedi', 'TZS': 'Tanzanian Shilling',
};

// Currencies conventionally displayed without decimal places.
const List<String> _zeroDecimalCurrencies = [
  'IDR', 'JPY', 'KRW', 'VND', 'CLP', 'HUF', 'MMK', 'KHR', 'LAK', 'PYG', 'ISK',
];

String formatCurrency(double value, String currencyCode) {
  final isIdr = currencyCode == 'IDR';
  final symbol = currencySymbols[currencyCode] ?? '$currencyCode ';
  final zeroDecimal = _zeroDecimalCurrencies.contains(currencyCode);

  int decimals;
  if (zeroDecimal) {
    decimals = (value != 0 && value < 1) ? 2 : 0;
  } else if (value != 0 && value < 1) {
    decimals = 6;
  } else {
    decimals = 2;
  }

  final s = value.toStringAsFixed(decimals);
  final parts = s.split('.');
  final digits = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    buf.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buf.write(isIdr ? '.' : ',');
    }
  }
  var out = isIdr ? 'Rp ${buf.toString()}' : '$symbol${buf.toString()}';
  if (parts.length > 1 && decimals > 0) {
    out += (isIdr ? ',' : '.') + parts[1];
  }
  return out;
}

String formatCurrencyShort(double value, String currencyCode) {
  final symbol = currencySymbols[currencyCode] ?? '$currencyCode ';
  double v = value;
  String suffix = '';
  if (value >= 1000000000) {
    v = value / 1000000000;
    suffix = 'M';
  } else if (value >= 1000000) {
    v = value / 1000000;
    suffix = 'jt';
  } else if (value >= 1000) {
    v = value / 1000;
    suffix = 'rb';
  }
  final decimals = suffix.isEmpty ? (value < 100 ? 2 : 0) : 2;
  return '$symbol${v.toStringAsFixed(decimals)}$suffix';
}

// ---------------------------------------------------------------------------
// Friendly names for common coins (Binance only gives us ticker symbols).
// Anything not in this map just falls back to showing its symbol as name.
// ---------------------------------------------------------------------------

const Map<String, String> coinNames = {
  'BTC': 'Bitcoin', 'ETH': 'Ethereum', 'BNB': 'BNB', 'SOL': 'Solana',
  'XRP': 'XRP', 'ADA': 'Cardano', 'DOGE': 'Dogecoin', 'TRX': 'TRON',
  'AVAX': 'Avalanche', 'DOT': 'Polkadot', 'MATIC': 'Polygon',
  'LINK': 'Chainlink', 'LTC': 'Litecoin', 'SHIB': 'Shiba Inu',
  'ATOM': 'Cosmos', 'UNI': 'Uniswap', 'XLM': 'Stellar',
  'ETC': 'Ethereum Classic', 'FIL': 'Filecoin', 'APT': 'Aptos',
  'ARB': 'Arbitrum', 'OP': 'Optimism', 'NEAR': 'NEAR Protocol',
  'VET': 'VeChain', 'ICP': 'Internet Computer', 'ALGO': 'Algorand',
  'HBAR': 'Hedera', 'SAND': 'The Sandbox', 'MANA': 'Decentraland',
  'AAVE': 'Aave', 'EOS': 'EOS', 'XTZ': 'Tezos', 'THETA': 'Theta Network',
  'EGLD': 'MultiversX', 'FTM': 'Fantom', 'RUNE': 'THORChain',
  'GRT': 'The Graph', 'CHZ': 'Chiliz', 'KAVA': 'Kava', 'ZEC': 'Zcash',
  'DASH': 'Dash', 'WAVES': 'Waves', 'COMP': 'Compound', 'MKR': 'Maker',
  'SNX': 'Synthetix', 'CRV': 'Curve DAO', 'SUI': 'Sui', 'PEPE': 'Pepe',
  'WIF': 'dogwifhat', 'INJ': 'Injective', 'TIA': 'Celestia', 'SEI': 'Sei',
  'RNDR': 'Render', 'TON': 'Toncoin', 'USDC': 'USD Coin',
  'FDUSD': 'First Digital USD', 'TUSD': 'TrueUSD', 'DAI': 'Dai',
  'BONK': 'Bonk', 'FLOKI': 'Floki', 'GALA': 'Gala', 'IMX': 'Immutable',
  'STX': 'Stacks', 'ORDI': 'Ordi', 'JUP': 'Jupiter', 'PYTH': 'Pyth Network',
};

class Coin {
  final String symbol; // base asset, e.g. "BTC"
  final String name;
  final String image;
  final double priceUsd; // price quoted against USDT on Binance
  final double change24h;
  final double quoteVolume;

  Coin({
    required this.symbol,
    required this.name,
    required this.image,
    required this.priceUsd,
    required this.change24h,
    required this.quoteVolume,
  });

  /// Used as a stable key for favorites and as the Binance pair prefix.
  String get id => symbol;

  factory Coin.fromBinanceTicker(Map<String, dynamic> json) {
    final rawSymbol = json['symbol'] as String; // e.g. "BTCUSDT"
    final base = rawSymbol.substring(0, rawSymbol.length - 4);
    return Coin(
      symbol: base,
      name: coinNames[base] ?? base,
      image:
          'https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@master/128/color/${base.toLowerCase()}.png',
      priceUsd: double.tryParse(json['lastPrice']?.toString() ?? '') ?? 0,
      change24h:
          double.tryParse(json['priceChangePercent']?.toString() ?? '') ?? 0,
      quoteVolume:
          double.tryParse(json['quoteVolume']?.toString() ?? '') ?? 0,
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

  String _currency = 'USD';
  Map<String, double> _rates = {'USD': 1.0};
  DateTime? _ratesFetchedAt;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _searchCtrl.addListener(_applyFilter);
    _autoTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _fetchCoins(silent: true);
      _maybeRefreshRates();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRates = prefs.getString('rates_cache');
    setState(() {
      _favorites = (prefs.getStringList('favorites') ?? []).toSet();
      _currency = prefs.getString('currency') ?? 'USD';
      if (cachedRates != null) {
        try {
          final decoded = Map<String, dynamic>.from(jsonDecode(cachedRates));
          _rates = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
        } catch (_) {
          // ignore malformed cache
        }
      }
    });
    await _fetchRates();
    await _fetchCoins();
  }

  Future<void> _fetchRates() async {
    try {
      final res = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['result'] == 'success' && data['rates'] != null) {
          final rates = Map<String, dynamic>.from(data['rates']);
          final parsed =
              rates.map((k, v) => MapEntry(k, (v as num).toDouble()));
          setState(() => _rates = parsed);
          _ratesFetchedAt = DateTime.now();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('rates_cache', jsonEncode(parsed));
        }
      }
    } catch (_) {
      // Keep using whatever rates we already have (cached or USD-only).
    }
  }

  Future<void> _maybeRefreshRates() async {
    if (_ratesFetchedAt == null ||
        DateTime.now().difference(_ratesFetchedAt!) >
            const Duration(minutes: 10)) {
      await _fetchRates();
    }
  }

  Future<void> _setCurrency(String currency) async {
    if (currency == _currency) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() => _currency = currency);
    await prefs.setString('currency', currency);
    // No need to refetch coins: prices are already cached in USD and we
    // just recompute the display value with the new rate.
  }

  Future<void> _toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
    await prefs.setStringList('favorites', _favorites.toList());
    _applyFilter();
  }

  Future<void> _fetchCoins({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final list = data.where((e) {
          final s = (e['symbol'] as String?) ?? '';
          if (!s.endsWith('USDT')) return false;
          final base = s.substring(0, s.length - 4);
          if (base.isEmpty) return false;
          if (RegExp(r'(UP|DOWN|BULL|BEAR)$').hasMatch(base)) return false;
          if (RegExp(r'[0-9]').hasMatch(base)) return false;
          return true;
        }).map((e) => Coin.fromBinanceTicker(e)).toList();
        list.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
        setState(() {
          _coins = list.take(60).toList();
          _loading = false;
          _error = null;
          _lastUpdate = DateTime.now();
        });
        _applyFilter();
      } else if (res.statusCode == 429 && !silent) {
        setState(() {
          _error = 'Terlalu banyak request ke Binance. Tunggu sebentar.';
          _loading = false;
        });
      } else if (!silent) {
        setState(() {
          _error = 'Server error (${res.statusCode}). Coba lagi sebentar.';
          _loading = false;
        });
      }
    } catch (e) {
      if (!silent) {
        setState(() {
          _error = 'Gagal memuat data. Cek koneksi internet kamu.';
          _loading = false;
        });
      }
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    var list = q.isEmpty
        ? List<Coin>.from(_coins)
        : _coins
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.symbol.toLowerCase().contains(q))
            .toList();
    list.sort((a, b) {
      final favA = _favorites.contains(a.id) ? 0 : 1;
      final favB = _favorites.contains(b.id) ? 0 : 1;
      return favA.compareTo(favB);
    });
    setState(() => _filtered = list);
  }

  double _rateFor(String code) => _rates[code] ?? 1.0;

  double _priceIn(Coin c) => c.priceUsd * _rateFor(_currency);

  String get _updateLabel {
    if (_lastUpdate == null) return '';
    final t = _lastUpdate!;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Update ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  Future<void> _showCurrencyPicker() async {
    final codes = _rates.keys.toList()..sort();
    if (!codes.contains('USD')) codes.insert(0, 'USD');
    String query = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final filtered = codes.where((code) {
            final name = (currencyNames[code] ?? '').toLowerCase();
            final q = query.toLowerCase();
            return code.toLowerCase().contains(q) || name.contains(q);
          }).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Pilih Mata Uang',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari kode atau nama mata uang...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setModalState(() => query = v),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final code = filtered[i];
                      final isSelected = code == _currency;
                      return ListTile(
                        leading: SizedBox(
                          width: 32,
                          child: Text(
                            currencySymbols[code] ?? code,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        title: Text(code,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          currencyNames[code] ?? '',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check,
                                color: Color(0xFFF0B90B))
                            : null,
                        onTap: () => Navigator.pop(ctx, code),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    if (selected != null) _setCurrency(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto Converter',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => _fetchCoins(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari coin... (BTC, Ethereum, dll)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: GestureDetector(
              onTap: _showCurrencyPicker,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.public,
                        size: 18, color: Color(0xFFF0B90B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_currency  •  ${currencyNames[_currency] ?? _currency}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down,
                        size: 20, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('LIVE',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(_updateLabel,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _fetchCoins(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchRates();
        await _fetchCoins();
      },
      child: ListView.builder(
        itemCount: _filtered.length,
        itemBuilder: (context, i) {
          final c = _filtered[i];
          final up = c.change24h >= 0;
          final isFav = _favorites.contains(c.id);
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                c.image,
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.currency_bitcoin, size: 36),
              ),
            ),
            title: Text(c.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c.symbol,
                style: const TextStyle(color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatCurrency(_priceIn(c), _currency),
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${up ? '+' : ''}${c.change24h.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color:
                            up ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? const Color(0xFFF0B90B) : Colors.grey,
                    size: 22,
                  ),
                  onPressed: () => _toggleFavorite(c.id),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailPage(
                    coin: c,
                    currency: _currency,
                    rate: _rateFor(_currency),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final Coin coin;
  final String currency;
  final double rate;

  const DetailPage({
    super.key,
    required this.coin,
    required this.currency,
    required this.rate,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _cryptoCtrl = TextEditingController(text: '1');
  final _fiatCtrl = TextEditingController();
  bool _syncing = false;
  bool _swapped = false;

  final List<Map<String, String>> _timeframes = [
    {'label': '1D', 'days': '1'},
    {'label': '7D', 'days': '7'},
    {'label': '1M', 'days': '30'},
    {'label': '3M', 'days': '90'},
    {'label': '1Y', 'days': '365'},
    {'label': 'All', 'days': 'max'},
  ];
  String _selectedDays = '1';

  // Chart data is in raw USDT prices from Binance klines, so it does NOT
  // depend on the selected fiat currency — only the timeframe.
  final Map<String, List<double>> _chartCache = {};
  List<double>? _chartData;
  bool _chartLoading = true;
  String? _chartError;

  double get _price => widget.coin.priceUsd * widget.rate;
  String get _fiatLabel => currencyNames[widget.currency] ?? widget.currency;
  String get _fiatPrefix =>
      '${currencySymbols[widget.currency] ?? widget.currency} ';

  @override
  void initState() {
    super.initState();
    final p = _price;
    _fiatCtrl.text = p.toStringAsFixed(p < 100 ? 2 : 0);
    _cryptoCtrl.addListener(_fromCrypto);
    _fiatCtrl.addListener(_fromFiat);
    _fetchChart();
  }

  @override
  void dispose() {
    _cryptoCtrl.dispose();
    _fiatCtrl.dispose();
    super.dispose();
  }

  void _fromCrypto() {
    if (_syncing) return;
    _syncing = true;
    final amount =
        double.tryParse(_cryptoCtrl.text.replaceAll(',', '.')) ?? 0;
    final fiat = amount * _price;
    _fiatCtrl.text = fiat == 0 ? '' : fiat.toStringAsFixed(fiat < 100 ? 2 : 0);
    _syncing = false;
    setState(() {});
  }

  void _fromFiat() {
    if (_syncing) return;
    _syncing = true;
    final fiat = double.tryParse(_fiatCtrl.text.replaceAll(',', '.')) ?? 0;
    final amount = _price == 0 ? 0.0 : fiat / _price;
    _cryptoCtrl.text = amount == 0 ? '' : amount.toStringAsFixed(8);
    _syncing = false;
    setState(() {});
  }

  Map<String, dynamic> _klineParamsFor(String days) {
    switch (days) {
      case '1':
        return {'interval': '15m', 'limit': 96};
      case '7':
        return {'interval': '1h', 'limit': 168};
      case '30':
        return {'interval': '4h', 'limit': 180};
      case '90':
        return {'interval': '1d', 'limit': 90};
      case '365':
        return {'interval': '1d', 'limit': 365};
      default: // 'max'
        return {'interval': '1w', 'limit': 500};
    }
  }

  Future<void> _fetchChart() async {
    final cacheKey = _selectedDays;
    if (_chartCache.containsKey(cacheKey)) {
      setState(() {
        _chartData = _chartCache[cacheKey];
        _chartLoading = false;
        _chartError = null;
      });
      return;
    }
    setState(() {
      _chartLoading = true;
      _chartError = null;
    });
    try {
      final params = _klineParamsFor(_selectedDays);
      final symbol = '${widget.coin.symbol}USDT';
      final url = Uri.parse(
        'https://api.binance.com/api/v3/klines'
        '?symbol=$symbol&interval=${params['interval']}&limit=${params['limit']}',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final points = data
            .map<double>((k) => double.tryParse(k[4].toString()) ?? 0)
            .toList();
        _chartCache[cacheKey] = points;
        setState(() {
          _chartData = points;
          _chartLoading = false;
        });
      } else if (res.statusCode == 429) {
        setState(() {
          _chartError =
              'Terlalu banyak request. Tunggu sebentar lalu coba lagi.';
          _chartLoading = false;
        });
      } else {
        setState(() {
          _chartError = 'Gagal memuat grafik (${res.statusCode}).';
          _chartLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _chartError = 'Gagal memuat grafik. Cek koneksi kamu.';
        _chartLoading = false;
      });
    }
  }

  double get _rangeChange {
    if (_chartData == null || _chartData!.length < 2) return 0;
    final first = _chartData!.first;
    final last = _chartData!.last;
    if (first == 0) return 0;
    return (last - first) / first * 100;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.coin;
    final up = _rangeChange >= 0;
    final chartColor = up ? Colors.greenAccent : Colors.redAccent;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                c.image,
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.currency_bitcoin, size: 28),
              ),
            ),
            const SizedBox(width: 8),
            Text(c.symbol),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(c.name,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              formatCurrency(_price, widget.currency),
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (!_chartLoading && _chartData != null)
              Text(
                '${up ? '+' : ''}${_rangeChange.toStringAsFixed(2)}%  (${_timeframes.firstWhere((t) => t['days'] == _selectedDays)['label']})',
                style: TextStyle(
                    color: chartColor, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: _buildChart(chartColor),
            ),
            const SizedBox(height: 8),
            if (!_chartLoading &&
                _chartData != null &&
                _chartData!.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Low: ${formatCurrencyShort(_chartData!.reduce((a, b) => a < b ? a : b) * widget.rate, widget.currency)}',
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12),
                  ),
                  Text(
                    'High: ${formatCurrencyShort(_chartData!.reduce((a, b) => a > b ? a : b) * widget.rate, widget.currency)}',
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 12),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _timeframes.map((t) {
                  final selected = t['days'] == _selectedDays;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t['label']!),
                      selected: selected,
                      selectedColor: const Color(0xFFF0B90B),
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedDays = t['days']!);
                        _fetchChart();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            if (!_swapped) _buildCryptoField(c) else _buildFiatField(),
            const SizedBox(height: 8),
            Center(
              child: IconButton(
                onPressed: () => setState(() => _swapped = !_swapped),
                icon: const Icon(Icons.swap_vert, color: Color(0xFFF0B90B)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF161B22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!_swapped) _buildFiatField() else _buildCryptoField(c),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                final text =
                    '${_cryptoCtrl.text} ${c.symbol} = $_fiatPrefix${_fiatCtrl.text}';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Hasil disalin ke clipboard')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Salin Hasil'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoField(Coin c) {
    return Column(
      key: const ValueKey('crypto_field'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Jumlah ${c.symbol}',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: _cryptoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF161B22),
            suffixText: c.symbol,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiatField() {
    return Column(
      key: const ValueKey('fiat_field'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Jumlah $_fiatLabel',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: _fiatCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF161B22),
            prefixText: _fiatPrefix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChart(Color color) {
    if (_chartLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chartError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_chartError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _fetchChart,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    if (_chartData == null || _chartData!.length < 2) {
      return const Center(child: Text('Data grafik tidak tersedia'));
    }
    return CustomPaint(
      painter: LineChartPainter(data: _chartData!, color: color),
      child: Container(),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  LineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minV = data.reduce((a, b) => a < b ? a : b);
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final y = size.height / 4 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y =
          size.height - ((data[i] - minV) / range) * size.height * 0.92 -
              size.height * 0.04;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.30),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant LineChartPainter old) =>
      old.data != data || old.color != color;
}
