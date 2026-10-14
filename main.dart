import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const WeatherRpgApp());

const Color night = Color(0xFF061326);
const Color panel = Color(0xFF0B1D33);
const Color panel2 = Color(0xFF102844);
const Color cyan = Color(0xFF47C9FF);
const Color pale = Color(0xFFEAF7FF);
const Color muted = Color(0xFF9ABAD1);
const Color gold = Color(0xFFFFC857);
const Color danger = Color(0xFFFF5B70);

class WeatherRpgApp extends StatefulWidget {
  const WeatherRpgApp({super.key});

  @override
  State<WeatherRpgApp> createState() => _WeatherRpgAppState();
}

class _WeatherRpgAppState extends State<WeatherRpgApp> {
  ThemeMode themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather RPG',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF167BC1)),
        scaffoldBackgroundColor: const Color(0xFFEAF3FC),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: night,
        colorScheme: ColorScheme.fromSeed(
          seedColor: cyan,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: WeatherHome(
        onThemeChanged: (mode) => setState(() => themeMode = mode),
        themeMode: themeMode,
      ),
    );
  }
}

class WeatherHome extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode themeMode;
  const WeatherHome({
    super.key,
    required this.onThemeChanged,
    required this.themeMode,
  });

  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome>
    with TickerProviderStateMixin {
  late final AnimationController _weatherAnimation;
  WeatherBundle? _weather;
  bool _loading = true;
  String? _error;
  int _tab = 0;
  String _city = 'Mumbai';
  String _region = 'Maharashtra, India';
  double _lat = 19.0760;
  double _lon = 72.8777;
  String _unit = '°C';
  bool _fahrenheit = false;
  final Set<String> _savedCities = {'Mumbai|Maharashtra, India'};

  @override
  void initState() {
    super.initState();
    _weatherAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat();
    _fetchWeather();
  }

  @override
  void dispose() {
    _weatherAnimation.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$_lat',
        'longitude': '$_lon',
        'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,'
            'is_day,precipitation,rain,weather_code,wind_speed_10m,wind_direction_10m',
        'hourly': 'temperature_2m,precipitation_probability,weather_code',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max,rain_sum,sunrise,sunset',
        'timezone': 'auto',
        'forecast_days': '7',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 18));
      if (response.statusCode != 200) {
        throw Exception('Weather service returned ${response.statusCode}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final result = WeatherBundle.fromJson(json);
      if (!mounted) return;
      setState(() {
        _weather = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Weather could not be loaded. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  Future<PlaceResult?> _geocode(String query) async {
    if (query.trim().isEmpty) return null;
    try {
      final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query.trim(),
        'count': '5',
        'language': 'en',
        'format': 'json',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final list = json['results'] as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      final item = list.first as Map<String, dynamic>;
      final city = (item['name'] ?? query).toString();
      final region = [
        if (item['admin1'] != null) item['admin1'].toString(),
        if (item['country'] != null) item['country'].toString(),
      ].join(', ');
      return PlaceResult(
        city: city,
        region: region,
        latitude: (item['latitude'] as num).toDouble(),
        longitude: (item['longitude'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _chooseCity() async {
    // Use a dedicated route instead of a dialog. This avoids the focus /
    // inherited-widget teardown path that can trigger framework assertions
    // on some Flutter/Android combinations when the keyboard is open.
    final result = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute<PlaceResult>(
        builder: (_) => CitySearchPage(searchCity: _geocode),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _city = result.city;
      _region = result.region;
      _lat = result.latitude;
      _lon = result.longitude;
      _tab = 0;
      _savedCities.add('${result.city}|${result.region}');
    });
    await _fetchWeather();
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? panel
          : Colors.white,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              const Text('Appearance'),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {widget.themeMode},
                onSelectionChanged: (value) {
                  widget.onThemeChanged(value.first);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 18),
              const Text('Temperature units'),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Celsius °C')),
                  ButtonSegment(value: true, label: Text('Fahrenheit °F')),
                ],
                selected: {_fahrenheit},
                onSelectionChanged: (value) {
                  setState(() {
                    _fahrenheit = value.first;
                    _unit = _fahrenheit ? '°F' : '°C';
                  });
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Weather data: Open-Meteo. Scene effects are decorative; alerts are not official emergency warnings.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(isDark),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchWeather,
                color: cyan,
                child: _loading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 220),
                          Center(child: CircularProgressIndicator()),
                          SizedBox(height: 220),
                        ],
                      )
                    : _error != null
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              const SizedBox(height: 100),
                              const Icon(Icons.cloud_off, size: 56, color: cyan),
                              const SizedBox(height: 16),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              Center(
                                child: FilledButton.icon(
                                  onPressed: _fetchWeather,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ),
                            ],
                          )
                        : _buildTab(isDark),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(isDark),
    );
  }

  Widget _topBar(bool isDark) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cyan.withOpacity(.13),
                border: Border.all(color: cyan.withOpacity(.55), width: 1.5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.bolt, color: cyan, size: 28),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WEATHER RPG',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      )),
                  Text('YOUR WORLD. YOUR WEATHER.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        letterSpacing: 1.15,
                      )),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Search city',
              onPressed: _chooseCity,
              icon: const Icon(Icons.location_on_outlined, color: cyan),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      );

  Widget _buildTab(bool isDark) {
    final weather = _weather!;
    switch (_tab) {
      case 1:
        return _hourlyScreen(weather, isDark);
      case 2:
        return _weeklyScreen(weather, isDark);
      case 3:
        return _placesScreen(isDark);
      default:
        return _homeScreen(weather, isDark);
    }
  }

  Widget _homeScreen(WeatherBundle w, bool isDark) {
    final c = w.current;
    final code = (c['weather_code'] as num).toInt();
    final isDay = (c['is_day'] as num?)?.toInt() == 1;
    final temp = _temp(c['temperature_2m']);
    final feels = _temp(c['apparent_temperature']);
    final condition = weatherLabel(code);
    final rainProb = _currentRainProbability(w);
    final storm = [95, 96, 99].contains(code);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      children: [
        _locationStrip(isDark),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _weatherAnimation,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 350,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/monsoon_forest.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                  ),
                  // Weather-reactive atmosphere: keep the crisp pixel forest,
                  // then tint it to match the live conditions before effects render.
                  Container(color: _sceneTint(code, isDay)),
                  CustomPaint(
                    painter: PixelStormPainter(
                      tick: _weatherAnimation.value,
                      storm: storm,
                      isDay: isDay,
                      weatherCode: code,
                    ),
                  ),
                  Stack(
                    children: [
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _hudTag(_sceneName(code), Icons.explore_outlined),
                      ),
                      // The explorer lives inside the world, not inside a UI badge.
                      Positioned(
                        left: 14 + (_weatherAnimation.value < .62 ? 0 : _weatherAnimation.value < .82 ? ((_weatherAnimation.value - .62) / .20) * 132 : 132),
                        bottom: 10 + (math.sin(_weatherAnimation.value * math.pi * 4).abs() * 2),
                        child: _LivingGoblin(
                          tick: _weatherAnimation.value,
                          weatherCode: code,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _hudTag(isDay ? 'DAYTIME' : 'NIGHTFALL',
                            isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _hudTag('PIXEL WORLD • LIVE', Icons.bolt),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _pixelPanel(
          isDark: isDark,
          borderColor: cyan,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(weatherEmoji(code, isDay),
                  style: const TextStyle(fontSize: 45)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$temp$_unit',
                        style: const TextStyle(
                          fontSize: 39,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.6,
                        )),
                    const SizedBox(height: 5),
                    Text(condition.toUpperCase(),
                        style: const TextStyle(
                          color: cyan,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          fontSize: 12,
                        )),
                    Text('Feels like $feels$_unit',
                        style: const TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('H ${_temp(w.daily['temperature_2m_max'][0])}°',
                      style: const TextStyle(color: danger, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text('L ${_temp(w.daily['temperature_2m_min'][0])}°',
                      style: const TextStyle(color: cyan, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.water_drop,
                value: '${c['relative_humidity_2m']}%',
                label: 'HUMIDITY',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                icon: Icons.air,
                value: '${(c['wind_speed_10m'] as num).round()} km/h',
                label: 'WIND',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                icon: Icons.umbrella,
                value: '${_number(c['precipitation'])} mm',
                label: 'RAIN NOW',
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _alertPanel(code: code, rainProbability: rainProb, isDark: isDark),
        const SizedBox(height: 20),
        _sectionHeader('HOURLY FORECAST', 'VIEW ALL', () => setState(() => _tab = 1)),
        const SizedBox(height: 9),
        _hourlyStrip(w, isDark, count: 6),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Forecast data by Open-Meteo • Pull down to refresh',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ),
      ],
    );
  }

  String _sceneName(int code) {
    if ([71, 73, 75, 77, 85, 86].contains(code)) return 'FROSTBOUND PEAK';
    if ([45, 48, 3].contains(code)) return 'MISTY BOG';
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99].contains(code)) return 'MONSOON REGION';
    if ([0, 1, 2].contains(code)) return 'SUNLIT WILDS';
    return 'MISTY FRONTIER';
  }

  Color _sceneTint(int code, bool isDay) {
    if ([71, 73, 75, 77, 85, 86].contains(code)) return const Color(0x553CAFEF);
    if ([45, 48, 3].contains(code)) return const Color(0x663A5870);
    if ([95, 96, 99].contains(code)) return const Color(0x554B50A5);
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return const Color(0x33215BA5);
    if ([0, 1, 2].contains(code)) return isDay ? const Color(0x11FFB52E) : const Color(0x55303B72);
    return const Color(0x00000000);
  }

  Widget _locationStrip(bool isDark) => InkWell(
        onTap: _chooseCity,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? panel : Colors.white,
            border: Border.all(color: cyan.withOpacity(.65), width: 1.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: cyan, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_city.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text(_region,
                        style: const TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.expand_more, color: cyan),
            ],
          ),
        ),
      );

  Widget _hudTag(String text, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE6061527),
          border: Border.all(color: cyan.withOpacity(.8)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cyan, size: 13),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(
                    color: pale, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .6)),
          ],
        ),
      );

  Widget _pixelPanel({
    required Widget child,
    required bool isDark,
    Color borderColor = const Color(0xFF2C5C83),
  }) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? panel.withOpacity(.98) : Colors.white,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(.08),
              blurRadius: 0,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      );

  Widget _metricCard({
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
  }) =>
      Container(
        padding: const EdgeInsets.fromLTRB(7, 11, 7, 10),
        decoration: BoxDecoration(
          color: isDark ? panel : Colors.white,
          border: Border.all(color: const Color(0xFF244A6A)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          children: [
            Icon(icon, color: cyan, size: 20),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: muted, fontSize: 8, letterSpacing: .8, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _alertPanel({
    required int code,
    required int rainProbability,
    required bool isDark,
  }) {
    final storm = [95, 96, 99].contains(code);
    final rainy = [51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code);
    final title = storm ? 'THUNDERSTORM CONDITIONS' : rainy ? 'RAIN IN THE REGION' : 'WEATHER QUEST';
    final message = storm
        ? 'Thunderstorm indicated by the forecast. Check official local alerts.'
        : rainy
            ? 'Rain is in the forecast. Keep your travel plans flexible.'
            : 'Clear skies ahead. Your next adventure awaits.';
    final color = storm ? danger : rainy ? gold : cyan;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? panel : Colors.white),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(storm ? Icons.warning_amber_rounded : rainy ? Icons.umbrella : Icons.auto_awesome,
              color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                    )),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(fontSize: 11, color: muted, height: 1.3)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: cyan),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback onTap) => Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                )),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 30),
            ),
            child: Text(action,
                style: const TextStyle(color: cyan, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
          const Icon(Icons.chevron_right, color: gold, size: 18),
        ],
      );

  Widget _hourlyStrip(WeatherBundle w, bool isDark, {int count = 24}) {
    final times = w.hourly['time'] as List<dynamic>;
    final temps = w.hourly['temperature_2m'] as List<dynamic>;
    final probs = w.hourly['precipitation_probability'] as List<dynamic>;
    final codes = w.hourly['weather_code'] as List<dynamic>;
    final start = _firstFutureHour(times);
    final end = math.min(start + count, times.length);
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: end - start,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, offset) {
          final i = start + offset;
          final date = DateTime.tryParse(times[i].toString());
          return Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
            decoration: BoxDecoration(
              color: isDark ? panel : Colors.white,
              border: Border.all(color: offset == 0 ? cyan : const Color(0xFF244A6A),
                  width: offset == 0 ? 1.5 : 1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(offset == 0 ? 'NOW' : _hourLabel(date),
                    style: const TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w800)),
                Text(weatherEmoji((codes[i] as num).toInt(), true),
                    style: const TextStyle(fontSize: 23)),
                Text('${_temp(temps[i])}$_unit',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.water_drop, size: 10, color: cyan),
                    Text('${probs[i]}%',
                        style: const TextStyle(color: cyan, fontSize: 10)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _weeklyCompact(WeatherBundle w, bool isDark) {
    final d = w.daily;
    final dates = d['time'] as List<dynamic>;
    final codes = d['weather_code'] as List<dynamic>;
    final highs = d['temperature_2m_max'] as List<dynamic>;
    final lows = d['temperature_2m_min'] as List<dynamic>;
    final rain = d['precipitation_probability_max'] as List<dynamic>;
    return _pixelPanel(
      isDark: isDark,
      child: Column(
        children: List.generate(dates.length, (i) {
          final date = DateTime.tryParse(dates[i].toString());
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 45,
                  child: Text(i == 0 ? 'Today' : _weekday(date),
                      style: const TextStyle(color: muted, fontSize: 11)),
                ),
                const SizedBox(width: 5),
                Text(weatherEmoji((codes[i] as num).toInt(), true),
                    style: const TextStyle(fontSize: 21)),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop, color: cyan, size: 11),
                      Text('${rain[i]}%',
                          style: const TextStyle(color: cyan, fontSize: 10)),
                    ],
                  ),
                ),
                Text('${_temp(lows[i])}°',
                    style: const TextStyle(color: muted, fontSize: 12)),
                const SizedBox(width: 13),
                SizedBox(
                  width: 34,
                  child: Text('${_temp(highs[i])}°',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _hourlyScreen(WeatherBundle w, bool isDark) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
        children: [
          _screenTitle('HOURLY FORECAST', 'Your next 24 hours'),
          const SizedBox(height: 16),
          _hourlyStrip(w, isDark, count: 24),
          const SizedBox(height: 18),
          _pixelPanel(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RAIN CHANCE BY HOUR',
                    style: TextStyle(color: cyan, fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 15),
                SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: RainChartPainter(
                      values: (w.hourly['precipitation_probability'] as List<dynamic>)
                          .skip(_firstFutureHour(w.hourly['time'] as List<dynamic>))
                          .take(12)
                          .map((v) => (v as num).toDouble())
                          .toList(),
                      color: cyan,
                      grid: const Color(0xFF244A6A),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Probability of precipitation (%)',
                    style: TextStyle(color: muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionHeader('NEXT 24 HOURS', 'REFRESH', _fetchWeather),
          const SizedBox(height: 8),
          _hourlyStrip(w, isDark, count: 24),
        ],
      );

  Widget _weeklyScreen(WeatherBundle w, bool isDark) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
        children: [
          _screenTitle('7 DAY FORECAST', 'The next chapter'),
          const SizedBox(height: 16),
          _weeklyCompact(w, isDark),
          const SizedBox(height: 16),
          _pixelPanel(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DAILY TEMPERATURE RANGE',
                    style: TextStyle(color: cyan, fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 12),
                ...List.generate((w.daily['time'] as List).length, (i) {
                  final low = (w.daily['temperature_2m_min'][i] as num).toDouble();
                  final high = (w.daily['temperature_2m_max'][i] as num).toDouble();
                  final minAll = (w.daily['temperature_2m_min'] as List)
                      .map((v) => (v as num).toDouble()).reduce(math.min);
                  final maxAll = (w.daily['temperature_2m_max'] as List)
                      .map((v) => (v as num).toDouble()).reduce(math.max);
                  final range = (maxAll - minAll).abs() < 0.1 ? 1.0 : maxAll - minAll;
                  final left = ((low - minAll) / range).clamp(0.0, 1.0).toDouble();
                  final width = ((high - low) / range).clamp(0.03, 1.0).toDouble();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            i == 0 ? 'Today' : _weekday(DateTime.tryParse(w.daily['time'][i])),
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 13,
                            child: LayoutBuilder(
                              builder: (context, constraints) => Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF203B54),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  Positioned(
                                    left: constraints.maxWidth * left,
                                    width: math.max(6.0, constraints.maxWidth * width),
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [cyan, gold],
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: Text('${_temp(low)}° / ${_temp(high)}°',
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      );

  Widget _placesScreen(bool isDark) {
    final places = _savedCities.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
      children: [
        _screenTitle('YOUR PLACES', 'Choose a weather world'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _chooseCity,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('ADD A LOCATION'),
        ),
        const SizedBox(height: 12),
        ...places.map((key) {
          final parts = key.split('|');
          final selected = parts.first == _city && (parts.length < 2 || parts[1] == _region);
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: InkWell(
              onTap: () async {
                if (selected) return;
                final result = await _geocode(parts.first);
                if (result == null || !mounted) return;
                setState(() {
                  _city = result.city;
                  _region = result.region;
                  _lat = result.latitude;
                  _lon = result.longitude;
                  _tab = 0;
                });
                await _fetchWeather();
              },
              child: _pixelPanel(
                isDark: isDark,
                borderColor: selected ? cyan : const Color(0xFF244A6A),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: cyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(parts.first.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w900)),
                          if (parts.length > 1)
                            Text(parts[1],
                                style: const TextStyle(color: muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle, color: cyan)
                    else
                      const Icon(Icons.chevron_right, color: muted),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        const Text(
          'Add a city by searching its name. Weather RPG uses city coordinates and does not request GPS permission in this starter.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _screenTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      );

  Widget _bottomNav(bool isDark) {
    const items = [
      (Icons.home_rounded, 'Today'),
      (Icons.schedule_rounded, 'Hourly'),
      (Icons.calendar_month_rounded, '7 Days'),
      (Icons.place_rounded, 'Places'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF06101E) : Colors.white,
        border: Border(top: BorderSide(color: cyan.withOpacity(.5), width: 1.2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (i) {
            final active = _tab == i;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.fromLTRB(4, 7, 4, 7),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? cyan.withOpacity(.13) : Colors.transparent,
                    border: Border.all(
                      color: active ? cyan : Colors.transparent,
                      width: 1.3,
                    ),
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: active
                        ? [BoxShadow(color: cyan.withOpacity(.12), blurRadius: 9)]
                        : [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i].$1, color: active ? cyan : muted, size: 22),
                      const SizedBox(height: 3),
                      Text(items[i].$2,
                          style: TextStyle(
                            color: active ? cyan : muted,
                            fontSize: 10,
                            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  int _temp(dynamic value) {
    final c = (value as num).toDouble();
    return (_fahrenheit ? c * 9 / 5 + 32 : c).round();
  }

  String _number(dynamic value) =>
      value is num ? value.toStringAsFixed(value.abs() < 10 ? 1 : 0) : '—';

  int _currentRainProbability(WeatherBundle w) {
    final times = w.hourly['time'] as List<dynamic>;
    final probs = w.hourly['precipitation_probability'] as List<dynamic>;
    final i = _firstFutureHour(times);
    if (i >= probs.length) return 0;
    return (probs[i] as num?)?.toInt() ?? 0;
  }

  int _firstFutureHour(List<dynamic> times) {
    final now = DateTime.now();
    final index = times.indexWhere((v) {
      final time = DateTime.tryParse(v.toString());
      return time != null && !time.isBefore(now.subtract(const Duration(hours: 1)));
    });
    return index < 0 ? 0 : index;
  }

  String _hourLabel(DateTime? time) {
    if (time == null) return '--';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$hour${time.hour >= 12 ? 'p' : 'a'}';
  }

  String _weekday(DateTime? date) {
    if (date == null) return '--';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}

class _LivingGoblin extends StatefulWidget {
  final double tick;
  final int weatherCode;
  const _LivingGoblin({required this.tick, required this.weatherCode});

  @override
  State<_LivingGoblin> createState() => _LivingGoblinState();
}

class _LivingGoblinState extends State<_LivingGoblin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cheer;

  @override
  void initState() {
    super.initState();
    _cheer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _cheer.dispose();
    super.dispose();
  }

  String _spriteFor(double tick) {
    // Every 10-second world cycle: idle, a short walk, then idle again.
    // The walk row is a real frame sequence cropped from the concept sprite sheet.
    if (tick >= .62 && tick < .82) {
      final frame = (((tick - .62) / .20) * 8).floor().clamp(0, 7);
      return 'assets/images/goblin_frames/walk_${frame.toString().padLeft(2, '0')}.png';
    }
    final frame = ((tick * 8).floor() % 8);
    return 'assets/images/goblin_frames/idle_${frame.toString().padLeft(2, '0')}.png';
  }

  @override
  Widget build(BuildContext context) {
    final snowy = [71, 73, 75, 77, 85, 86].contains(widget.weatherCode);
    final rainy = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
        .contains(widget.weatherCode);
    final bob = math.sin(widget.tick * math.pi * 8) * 2.2;
    final step = math.sin(widget.tick * math.pi * 2);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _cheer.forward(from: 0),
      child: AnimatedBuilder(
        animation: _cheer,
        builder: (context, child) {
          final cheerLift = math.sin(_cheer.value * math.pi) * 15;
          return Transform.translate(
            offset: Offset(step * 3, -bob - cheerLift),
            child: Transform.rotate(
              angle: math.sin(widget.tick * math.pi * 2) * .035,
              alignment: Alignment.bottomCenter,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0x99030A12),
                      borderRadius: BorderRadius.all(Radius.elliptical(30, 8)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 5),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Image.asset(
                      _spriteFor(widget.tick),
                      width: 112,
                      height: 130,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      gaplessPlayback: true,
                    ),
                  ),
                  if (rainy)
                    const Positioned(
                      top: 3,
                      right: 0,
                      child: Icon(Icons.water_drop, size: 12, color: Color(0xFF83DFFF)),
                    ),
                  if (snowy)
                    const Positioned(
                      top: 0,
                      left: 1,
                      child: Icon(Icons.ac_unit, size: 13, color: Color(0xFFDDF7FF)),
                    ),
                  if (_cheer.value > .05)
                    const Positioned(
                      top: -9,
                      right: -5,
                      child: Icon(Icons.auto_awesome, size: 18, color: gold),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


class CitySearchPage extends StatefulWidget {
  final Future<PlaceResult?> Function(String) searchCity;

  const CitySearchPage({super.key, required this.searchCity});

  @override
  State<CitySearchPage> createState() => _CitySearchPageState();
}

class _CitySearchPageState extends State<CitySearchPage> {
  final TextEditingController _controller = TextEditingController();
  bool _searching = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_searching) return;
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _message = 'Enter a city name first.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searching = true;
      _message = null;
    });

    PlaceResult? result;
    try {
      result = await widget.searchCity(query);
    } catch (_) {
      result = null;
    }

    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop<PlaceResult>(result);
    } else {
      setState(() {
        _searching = false;
        _message = 'City not found or network unavailable. Try another name.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHOOSE YOUR WORLD'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _searching ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 18),
            const Icon(Icons.travel_explore, color: cyan, size: 54),
            const SizedBox(height: 16),
            const Text(
              'Where is your next adventure?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Search for a city to load its current weather and forecast.',
              style: TextStyle(color: muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_searching,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'e.g. Delhi, Pune, Leh',
                prefixIcon: const Icon(Icons.search, color: cyan),
                filled: true,
                fillColor: isDark ? panel : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: const TextStyle(color: danger)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _searching ? null : _submit,
                icon: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_searching ? 'SEARCHING…' : 'SEARCH CITY'),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Try a city name rather than a street address. Location permission is not required.',
              style: TextStyle(color: muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class WeatherBundle {
  final Map<String, dynamic> current;
  final Map<String, dynamic> hourly;
  final Map<String, dynamic> daily;
  WeatherBundle({required this.current, required this.hourly, required this.daily});

  factory WeatherBundle.fromJson(Map<String, dynamic> json) => WeatherBundle(
        current: Map<String, dynamic>.from(json['current'] as Map),
        hourly: Map<String, dynamic>.from(json['hourly'] as Map),
        daily: Map<String, dynamic>.from(json['daily'] as Map),
      );
}

class PlaceResult {
  final String city;
  final String region;
  final double latitude;
  final double longitude;
  PlaceResult({
    required this.city,
    required this.region,
    required this.latitude,
    required this.longitude,
  });
}

String weatherLabel(int code) {
  if (code == 0) return 'Clear sky';
  if (code == 1) return 'Mainly clear';
  if (code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if ([45, 48].contains(code)) return 'Fog';
  if ([51, 53, 55, 56, 57].contains(code)) return 'Drizzle';
  if ([61, 63, 65, 66, 67].contains(code)) return 'Rain';
  if ([71, 73, 75, 77, 85, 86].contains(code)) return 'Snow';
  if ([80, 81, 82].contains(code)) return 'Rain showers';
  if ([95, 96, 99].contains(code)) return 'Thunderstorm';
  return 'Changing conditions';
}

String weatherEmoji(int code, bool day) {
  if (code == 0) return day ? '☀️' : '🌙';
  if ([1, 2].contains(code)) return day ? '🌤️' : '☁️';
  if (code == 3) return '☁️';
  if ([45, 48].contains(code)) return '🌫️';
  if ([51, 53, 55, 56, 57].contains(code)) return '🌦️';
  if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return '🌧️';
  if ([71, 73, 75, 77, 85, 86].contains(code)) return '❄️';
  if ([95, 96, 99].contains(code)) return '⛈️';
  return '🌥️';
}

class PixelStormPainter extends CustomPainter {
  final double tick;
  final bool storm;
  final bool isDay;
  final int weatherCode;
  PixelStormPainter({required this.tick, required this.storm, required this.isDay, required this.weatherCode});

  final math.Random _random = math.Random(23);

  @override
  void paint(Canvas canvas, Size size) {
    // Transparent animated overlays: the detailed forest is an image asset.
    // Warm lantern pulse near the left-centre of the scene.
    final pulse = .5 + .5 * math.sin(tick * math.pi * 2);
    final lanternCenter = Offset(size.width * .49, size.height * .47);
    final lanternGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromRGBO(255, 181, 57, .12 + pulse * .13),
          Color.fromRGBO(255, 150, 35, .045 + pulse * .035),
          const Color(0x00FF9B22),
        ],
        stops: const [0, .42, 1],
      ).createShader(Rect.fromCircle(
        center: lanternCenter,
        radius: size.width * (.14 + pulse * .025),
      ));
    canvas.drawCircle(lanternCenter, size.width * (.14 + pulse * .025), lanternGlow);

    // A slow-moving cool ambient wash keeps the forest from feeling like a flat card.
    final ambientWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF2B9BC8).withOpacity(.025 + pulse * .025),
          const Color(0x00061527),
          const Color(0xFFFFB34D).withOpacity(.025 + pulse * .035),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, ambientWash);

    // Fireflies and drifting dust: deterministic paths keep the animation stable.
    final ambient = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 18; i++) {
      final phase = tick * math.pi * 2 + i * 1.71;
      final x = ((i * 67.0 / size.width) + tick * (.12 + (i % 3) * .025)) % 1.0;
      final y = .20 + ((i * 31) % 63) / 100 + math.sin(phase) * .018;
      final radius = 1.0 + (i % 3) * .45;
      final alpha = (.22 + .55 * (.5 + .5 * math.sin(phase * 1.7))).clamp(0.0, 1.0).toDouble();
      ambient.color = (i % 3 == 0 ? const Color(0xFFFFD978) : const Color(0xFF9FE8FF))
          .withOpacity(alpha);
      canvas.drawCircle(Offset(x * size.width, y * size.height), radius, ambient);
    }

    if (storm && tick > .52 && tick < .66) {
      final glow = Paint()..color = const Color(0xFF2B9FFF).withOpacity(.12);
      canvas.drawRect(Offset.zero & size, glow);
      final lightning = Paint()
        ..color = const Color(0xFFB7F5FF)
        ..strokeWidth = math.max(2.0, size.width * .008)
        ..strokeJoin = StrokeJoin.miter
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(size.width * .64, 0)
        ..lineTo(size.width * .57, size.height * .20)
        ..lineTo(size.width * .62, size.height * .20)
        ..lineTo(size.width * .49, size.height * .47)
        ..lineTo(size.width * .55, size.height * .45)
        ..lineTo(size.width * .43, size.height * .68);
      canvas.drawPath(path, lightning);
    }

    final snowy = [71, 73, 75, 77, 85, 86].contains(weatherCode);
    final rainy = storm || [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(weatherCode);
    final foggy = [3, 45, 48].contains(weatherCode);
    if (rainy) {
      final rain = Paint()
        ..color = const Color(0xFF7CDEFF).withOpacity(storm ? .78 : .40)
        ..strokeWidth = 1.2;
      final count = storm ? 95 : 48;
      for (int i = 0; i < count; i++) {
        final x = (i * 47.0 + tick * size.width * .75) % size.width;
        final y = (i * 29.0 + tick * size.height * 1.5) % size.height;
        canvas.drawLine(Offset(x, y), Offset(x - 3.5, y + 8), rain);
      }
    } else if (snowy) {
      final snow = Paint()..color = const Color(0xFFE5F8FF).withOpacity(.88);
      for (int i = 0; i < 55; i++) {
        final x = (i * 37.0 + math.sin(tick * 6 + i) * 8) % size.width;
        final y = (i * 23.0 + tick * size.height * .55) % size.height;
        canvas.drawRect(Rect.fromLTWH(x, y, 2.5, 2.5), snow);
      }
    } else if (foggy) {
      final mist = Paint()..color = const Color(0xFFB9D3DF).withOpacity(.10);
      for (int i = 0; i < 4; i++) {
        final y = size.height * (.30 + i * .16);
        canvas.drawRect(Rect.fromLTWH((tick * 20 + i * 31) % size.width - 50, y, size.width * .72, 12), mist);
      }
    } else if (weatherCode <= 2 && isDay) {
      final glow = Paint()..color = const Color(0xFFFFD166).withOpacity(.09);
      canvas.drawCircle(Offset(size.width * .82, size.height * .20), size.width * .19, glow);
    }
  }

  @override
  bool shouldRepaint(covariant PixelStormPainter oldDelegate) =>
      oldDelegate.tick != tick || oldDelegate.storm != storm || oldDelegate.isDay != isDay || oldDelegate.weatherCode != weatherCode;
}

class RainChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color grid;
  RainChartPainter({required this.values, required this.color, required this.grid});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.isEmpty) return;
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = size.height - (values[i].clamp(0, 100) / 100) * size.height;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..shader = LinearGradient(
        colors: [color.withOpacity(.30), color.withOpacity(.01)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    for (final p in points) {
      canvas.drawCircle(p, 3.5, Paint()..color = color);
      canvas.drawCircle(p, 1.5, Paint()..color = night);
    }
  }

  @override
  bool shouldRepaint(covariant RainChartPainter oldDelegate) => oldDelegate.values != values;
}
