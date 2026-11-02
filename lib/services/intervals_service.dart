// Intervals.icu (free personal API key): activities, GPS routes and heart rate, no Health Connect needed.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'import_parser.dart';

class IntervalsResult {
  final List<Map<String, dynamic>> acts; final int total, stravaSkipped, known; final String? error;
  IntervalsResult(this.acts, this.total, this.stravaSkipped, this.known, [this.error]);
}

class IntervalsService {
  static const _kKey = 'icu_key', _kAthlete = 'icu_athlete', _kLast = 'icu_last';
  static const _base = 'https://intervals.icu/api/v1';

  static Future<(String, String)?> credentials() async {
    final p = await SharedPreferences.getInstance();
    final k = p.getString(_kKey) ?? '';
    if (k.isEmpty) return null;
    return (k, p.getString(_kAthlete) ?? '0');
  }
  static Future<void> save(String key, String athlete) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kKey, key.trim());
    await p.setString(_kAthlete, athlete.trim().isEmpty ? '0' : athlete.trim());
  }
  static Future<void> forget() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kKey); await p.remove(_kAthlete); await p.remove(_kLast);
  }
  static Future<DateTime?> lastSync() async {
    final ms = (await SharedPreferences.getInstance()).getInt(_kLast);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
  static Future<void> markSynced() async => (await SharedPreferences.getInstance()).setInt(_kLast, DateTime.now().millisecondsSinceEpoch);

  static Map<String, String> _headers(String key) => {
        // user "API_KEY", password = the key. A browser-like agent avoids Cloudflare challenges.
        'Authorization': 'Basic ${base64Encode(utf8.encode('API_KEY:$key'))}',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) HealthStats',
        'Accept': 'application/json',
      };

  static String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String? _httpError(int code, bool fr) {
    if (code == 200) return null;
    if (code == 401 || code == 403) return fr ? 'Clé API refusée. Vérifie la clé (et l’ID athlète si tu en as mis un).' : 'API key refused. Check the key (and athlete ID if set).';
    if (code == 429) return fr ? 'Trop de requêtes : réessaie dans quelques minutes.' : 'Too many requests: try again in a few minutes.';
    return fr ? 'Erreur Intervals.icu ($code).' : 'Intervals.icu error ($code).';
  }

  /// Quick test of the key: GET the athlete. Returns (ok, athlete name, error text).
  static Future<(bool, String?, String?)> check(String key, String athlete, bool fr) async {
    try {
      final r = await http.get(Uri.parse('$_base/athlete/$athlete'), headers: _headers(key)).timeout(const Duration(seconds: 20));
      final e = _httpError(r.statusCode, fr);
      if (e != null) return (false, null, e);
      String? name;
      try {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        final m = j is Map ? (j['athlete'] is Map ? j['athlete'] as Map : j) : null;
        final n = '${m?['name'] ?? m?['firstname'] ?? ''}'.trim();
        if (n.isNotEmpty) name = n;
      } catch (_) {}
      return (true, name, null);
    } catch (_) { return (false, null, fr ? 'Pas de connexion à Intervals.icu.' : 'Cannot reach Intervals.icu.'); }
  }

  /// Lists the activities of the last [days] days, then reads GPS + heart rate of the ones not known yet.
  static Future<IntervalsResult> fetch({required String key, required String athlete, required int days, required bool fr,
      required bool Function(int startMs) isKnown, void Function(String stage, double progress)? onStage}) async {
    final h = _headers(key);
    final now = DateTime.now();
    final uri = Uri.parse('$_base/athlete/$athlete/activities?oldest=${_d(now.subtract(Duration(days: days)))}&newest=${_d(now.add(const Duration(days: 1)))}');
    http.Response r;
    try { r = await http.get(uri, headers: h).timeout(const Duration(seconds: 45)); }
    catch (_) { return IntervalsResult([], 0, 0, 0, fr ? 'Pas de connexion à Intervals.icu.' : 'Cannot reach Intervals.icu.'); }
    final err = _httpError(r.statusCode, fr);
    if (err != null) return IntervalsResult([], 0, 0, 0, err);
    final list = (jsonDecode(utf8.decode(r.bodyBytes)) as List).whereType<Map>().toList();

    var strava = 0, known = 0;
    final todo = <(Map, int, int)>[]; // activity, startMs, elapsed seconds
    for (final a in list) {
      if ((a['source'] ?? '').toString().toUpperCase() == 'STRAVA' || a['_note'] != null) { strava++; continue; } // Strava data isn't available by API
      final sd = (a['start_date'] ?? a['start_date_local'])?.toString();
      final st = sd == null ? null : DateTime.tryParse(sd);
      if (st == null) continue;
      final ms = st.millisecondsSinceEpoch;
      if (isKnown(ms)) { known++; continue; }
      final el = ((a['elapsed_time'] ?? a['moving_time'] ?? 0) as num).toInt();
      todo.add((a, ms, el));
    }

    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < todo.length; i += 4) {
      final chunk = todo.skip(i).take(4).toList();
      final res = await Future.wait(chunk.map((c) => _one(c.$1, c.$2, c.$3, h)));
      for (final m in res) { if (m != null) out.add(m); }
      onStage?.call(fr ? 'Lecture des tracés ${(i + 4).clamp(0, todo.length)} / ${todo.length}…' : 'Reading routes ${(i + 4).clamp(0, todo.length)} / ${todo.length}…',
          todo.isEmpty ? 1 : ((i + 4) / todo.length).clamp(0.0, 1.0).toDouble());
    }
    return IntervalsResult(out, list.length, strava, known);
  }

  static Future<Map<String, dynamic>?> _one(Map a, int startMs, int elapsed, Map<String, String> h) async {
    try {
      final id = a['id'];
      final pts = <List<double>>[];
      try {
        final r = await http.get(Uri.parse('$_base/activity/$id/streams?types=time,latlng,heartrate,altitude'), headers: h)
            .timeout(const Duration(seconds: 40));
        if (r.statusCode == 200) {
          final by = <String, Map>{};
          for (final e in jsonDecode(utf8.decode(r.bodyBytes)) as List) { if (e is Map && e['type'] != null) by['${e['type']}'] = e; }
          List? col(String t) => by[t]?['data'] as List?;
          final ll = col('latlng'), ll2 = by['latlng']?['data2'] as List?, hr = col('heartrate'), alt = col('altitude'), tm = col('time');
          final n = [ll?.length ?? 0, hr?.length ?? 0].reduce((x, y) => x > y ? x : y);
          double num0(dynamic v) => v is num ? v.toDouble() : 0;
          for (var i = 0; i < n; i++) {
            double lat = 0, lng = 0;
            if (ll != null && i < ll.length && ll[i] != null) {
              if (ll[i] is List) { lat = num0((ll[i] as List)[0]); lng = num0((ll[i] as List)[1]); }
              else { lat = num0(ll[i]); lng = ll2 != null && i < ll2.length ? num0(ll2[i]) : 0; }
            }
            final t = tm != null && i < tm.length ? num0(tm[i]) : i.toDouble();
            pts.add([lat, lng, alt != null && i < alt.length ? num0(alt[i]) : 0, startMs + t * 1000,
                hr != null && i < hr.length && hr[i] is num ? (hr[i] as num).toDouble() : -1]);
          }
        }
      } catch (_) { /* no streams: summary only */ }
      final end = startMs + (elapsed > 0 ? elapsed : ((a['moving_time'] ?? 0) as num).toInt()) * 1000;
      final m = buildActivity(pts: pts, type: sportFromName('${a['type'] ?? ''}'), title: '${a['name'] ?? ''}',
          distanceM: (a['distance'] as num?)?.toDouble(), kcal: ((a['calories'] ?? a['icu_calories']) as num?)?.toDouble(),
          startMs: startMs.toDouble(), endMs: end.toDouble().clamp(startMs + 1000.0, double.infinity).toDouble());
      if (m == null) return null;
      if ((m['hrAvg'] as num) <= 0 && a['average_heartrate'] is num) {
        m['hrAvg'] = (a['average_heartrate'] as num).toDouble();
        m['hrMax'] = ((a['max_heartrate'] ?? a['average_heartrate']) as num).toDouble();
        m['hrMin'] = m['hrAvg'];
      }
      m['source'] = 'intervals';
      return m;
    } catch (_) { return null; }
  }
}
