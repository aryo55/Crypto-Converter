import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    _fetchCoins();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCoins() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets'
        '?vs_currency=idr&order=market_cap_desc&per_page=50&page=1'
        '&price_change_percentage=24h',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _coins = data.map((e) => Coin.fromJson(e)).toList();
          _loading = false;
        });
        _applyFilter();
      } else {
        setState(() {
          _error = 'Server error (${res.statusCode}). Coba lagi sebentar.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data. Cek koneksi internet kamu.';
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _coins
          : _coins
              .where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.symbol.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto ke IDR',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _fetchCoins,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
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
              onPressed: _fetchCoins,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchCoins,
      child: ListView.builder(
        itemCount: _filtered.length,
        itemBuilder: (context, i) {
          final c = _filtered[i];
          final up = c.change24h >= 0;
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
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatIdr(c.priceIdr),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${up ? '+' : ''}${c.change24h.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: up ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailPage(coin: c),
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

  const DetailPage({super.key, required this.coin});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _amountCtrl = TextEditingController(text: '1');
  double _result = 0;

  final List<Map<String, String>> _timeframes = [
    {'label': '1D', 'days': '1'},
    {'label': '7D', 'days': '7'},
    {'label': '1M', 'days': '30'},
    {'label': '3M', 'days': '90'},
    {'label': '1Y', 'days': '365'},
    {'label': 'All', 'days': 'max'},
  ];
  String _selectedDays = '1';

  final Map<String, List<double>> _chartCache = {};
  List<double>? _chartData;
  bool _chartLoading = true;
  String? _chartError;

  @override
  void initState() {
    super.initState();
    _calc();
    _amountCtrl.addListener(_calc);
    _fetchChart();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _calc() {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    setState(() => _result = amount * widget.coin.priceIdr);
  }

  Future<void> _fetchChart() async {
    if (_chartCache.containsKey(_selectedDays)) {
      setState(() {
        _chartData = _chartCache[_selectedDays];
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
      final url = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/${widget.coin.id}/market_chart'
        '?vs_currency=idr&days=$_selectedDays',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List prices = data['prices'] ?? [];
        final points =
            prices.map<double>((p) => (p[1] as num).toDouble()).toList();
        _chartCache[_selectedDays] = points;
        setState(() {
          _chartData = points;
          _chartLoading = false;
        });
      } else if (res.statusCode == 429) {
        setState(() {
          _chartError = 'Terlalu banyak request. Tunggu sebentar lalu coba lagi.';
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
                style:
                    const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              formatIdr(c.priceIdr),
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
                    'Low: ${formatIdrShort(_chartData!.reduce((a, b) => a < b ? a : b))}',
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12),
                  ),
                  Text(
                    'High: ${formatIdrShort(_chartData!.reduce((a, b) => a > b ? a : b))}',
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
            Text('Jumlah ${c.symbol}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Hasil Konversi',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      formatIdr(_result),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF0B90B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: formatIdr(_result)));
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
            ),
          ],
        ),
      ),
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
