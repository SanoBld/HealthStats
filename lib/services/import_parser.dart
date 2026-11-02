// Reads GPX / FIT files (also .gz and Strava export .zip) into plain maps.
// Everything here runs in a background isolate and returns only simple data.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Parses every file; returns one map per activity found + a list of problems.
Future<({List<Map<String, dynamic>> acts, List<String> errors})> parseImportFiles(List<String> paths) =>
    Isolate.run(() => _parseAll(paths));

({List<Map<String, dynamic>> acts, List<String> errors}) _parseAll(List<String> paths) {
  final acts = <Map<String, dynamic>>[];
  final errors = <String>[];
  final meta = <String, (String, String)>{}; // Strava activities.csv: file name -> (title, sport)

  void handle(String name, Uint8List bytes) {
    var n = name.toLowerCase();
    try {
      if (n.endsWith('.gz')) { bytes = Uint8List.fromList(GZipCodec().decode(bytes)); n = n.substring(0, n.length - 3); }
      Map<String, dynamic>? a;
      if (n.endsWith('.gpx')) {
        a = _parseGpx(utf8.decode(bytes, allowMalformed: true));
      } else if (n.endsWith('.fit')) {
        a = _parseFit(bytes);
      } else { return; }
      if (a == null) { errors.add(name); return; }
      final base = name.split('/').last.split('\\').last;
      final m = meta[name.toLowerCase()] ?? meta[base.toLowerCase()];
      if (m != null) {
        if (m.$1.isNotEmpty) a['title'] = m.$1;
        final t = _sportFromName(m.$2);
        if (t != null) { a['type'] = t; a['guessed'] = false; }
      }
      a['file'] = base;
      acts.add(a);
    } catch (_) { errors.add(name); }
  }

  for (final p in paths) {
    try {
      final low = p.toLowerCase();
      final bytes = File(p).readAsBytesSync();
      if (low.endsWith('.zip')) {
        final arc = ZipDecoder().decodeBytes(bytes);
        for (final f in arc) {
          if (f.isFile && f.name.toLowerCase().endsWith('activities.csv')) {
            _readStravaCsv(utf8.decode(f.content as List<int>, allowMalformed: true), meta);
          }
        }
        for (final f in arc) {
          if (!f.isFile) continue;
          final n = f.name.toLowerCase();
          if (n.endsWith('.gpx') || n.endsWith('.fit') || n.endsWith('.gpx.gz') || n.endsWith('.fit.gz')) {
            handle(f.name, Uint8List.fromList(f.content as List<int>));
          }
        }
      } else if (low.endsWith('activities.csv') || low.endsWith('.csv')) {
        _readStravaCsv(utf8.decode(bytes, allowMalformed: true), meta);
      } else {
        handle(p, bytes);
      }
    } catch (_) { errors.add(p.split('/').last); }
  }
  return (acts: acts, errors: errors);
}

// ── Strava activities.csv ──
List<List<String>> _csv(String s) {
  final rows = <List<String>>[]; var row = <String>[]; final cur = StringBuffer(); var q = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (q) {
      if (c == '"') { if (i + 1 < s.length && s[i + 1] == '"') { cur.write('"'); i++; } else { q = false; } } else { cur.write(c); }
    } else if (c == '"') { q = true; }
    else if (c == ',') { row.add(cur.toString()); cur.clear(); }
    else if (c == '\n') { row.add(cur.toString().replaceAll('\r', '')); cur.clear(); rows.add(row); row = <String>[]; }
    else { cur.write(c); }
  }
  if (cur.isNotEmpty || row.isNotEmpty) { row.add(cur.toString()); rows.add(row); }
  return rows;
}

void _readStravaCsv(String text, Map<String, (String, String)> out) {
  final rows = _csv(text);
  if (rows.length < 2) return;
  final h = rows.first.map((e) => e.trim().toLowerCase()).toList();
  int col(List<String> names) { for (final n in names) { final i = h.indexOf(n); if (i >= 0) return i; } return -1; }
  final cf = col(['filename', 'nom du fichier']);
  final cn = col(['activity name', 'nom de l\'activité', 'nom de l’activité']);
  final ct = col(['activity type', 'type d\'activité', 'type d’activité']);
  if (cf < 0) return;
  for (final r in rows.skip(1)) {
    if (r.length <= cf || r[cf].isEmpty) continue;
    final file = r[cf].split('/').last.toLowerCase();
    out[r[cf].toLowerCase()] = (cn >= 0 && cn < r.length ? r[cn] : '', ct >= 0 && ct < r.length ? r[ct] : '');
    out[file] = out[r[cf].toLowerCase()]!;
  }
}

// ── Sport detection → Health Connect exercise type ──
int? _sportFromName(String raw) {
  final s = raw.toLowerCase().trim();
  if (s.isEmpty) return null;
  final indoor = s.contains('virtual') || s.contains('indoor') || s.contains('spin') || s.contains('trainer') || s.contains('treadmill') || s.contains('tapis') || s.contains('virtuel');
  if (s.contains('trail') || s.contains('run') || s.contains('course')) return indoor ? 57 : 56;
  if (s.contains('walk') || s.contains('marche')) return 79;
  if (s.contains('hik') || s.contains('rando')) return 37;
  if (s.contains('swim') || s.contains('nata') || s.contains('nage')) return s.contains('open') || s.contains('libre') ? 73 : 74;
  if (s.contains('bik') || s.contains('cycl') || s.contains('ride') || s.contains('vélo') || s.contains('velo')) return indoor ? 9 : 8;
  if (s.contains('row') || s.contains('aviron')) return indoor ? 54 : 53;
  if (s.contains('snowboard')) return 62;
  if (s.contains('snowshoe') || s.contains('raquette')) return 63;
  if (s.contains('ski')) return 61;
  if (s.contains('kayak') || s.contains('canoe') || s.contains('canoë') || s.contains('paddl')) return 46;
  if (s.contains('surf')) return 72;
  if (s.contains('sail') || s.contains('voile')) return 58;
  if (s.contains('skat') || s.contains('patin')) return s.contains('ice') || s.contains('glace') ? 39 : 60;
  if (s.contains('climb') || s.contains('escalade')) return 51;
  if (s.contains('yoga')) return 83;
  if (s.contains('pilates')) return 48;
  if (s.contains('weight') || s.contains('strength') || s.contains('muscu')) return 70;
  if (s.contains('hiit')) return 36;
  if (s.contains('elliptical') || s.contains('elliptique')) return 25;
  if (s.contains('stair') || s.contains('escalier')) return 68;
  if (s.contains('golf')) return 32;
  if (s.contains('soccer') || s.contains('football')) return 64;
  if (s.contains('tennis')) return 76;
  if (s.contains('wheelchair') || s.contains('fauteuil')) return 82;
  if (s.contains('dance') || s.contains('danse')) return 16;
  if (s == '1') return 8;   // Strava numeric codes
  if (s == '9') return 56;
  if (s == '16') return 74;
  if (s.contains('workout') || s.contains('other') || s.contains('autre')) return 0;
  return null;
}

int? _sportFromFit(int? sport, int? sub) {
  switch (sport) {
    case 1: return sub == 1 ? 57 : 56;
    case 2: return (sub == 5 || sub == 6) ? 9 : 8;
    case 21: return 8;
    case 5: return sub == 18 ? 73 : 74;
    case 11: return 79;
    case 17: case 16: return 37;
    case 15: return sub == 14 ? 54 : 53;
    case 12: case 13: return 61;
    case 14: return 62;
    case 19: case 37: case 41: return 46;
    case 6: return 5;
    case 7: return 64;
    case 8: return 76;
    case 9: return 28;
    case 25: return 32;
    case 30: return 60;
    case 31: return 51;
    case 32: return 58;
    case 33: return 39;
    case 35: return 63;
    case 38: return 72;
    case 47: return 11;
    case 4:
      return switch (sub) { 14 => 54, 15 => 25, 16 => 69, 20 => 70, _ => 0 };
    case 10:
      return switch (sub) { 20 => 70, 62 => 36, 43 => 83, 44 => 48, _ => 0 };
  }
  return null;
}

// ── Shared helpers ──
const _earth = 6371000.0;
double _hav(double la1, double lo1, double la2, double lo2) {
  final p1 = la1 * math.pi / 180, p2 = la2 * math.pi / 180;
  final dp = p2 - p1, dl = (lo2 - lo1) * math.pi / 180;
  final a = math.pow(math.sin(dp / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
  return 2 * _earth * math.asin(math.sqrt(a.toDouble()));
}

/// Builds the final map from raw points: [lat, lng, alt, timeMs, hr(or -1)].
Map<String, dynamic>? _finish({
  required List<List<double>> pts, required int? type, required String title,
  double? distanceM, double? kcal, double? sessionStartMs, double? sessionEndMs,
}) {
  if (pts.isEmpty && sessionStartMs == null) return null;
  final times = pts.where((p) => p[3] > 0).map((p) => p[3]).toList();
  final startMs = sessionStartMs ?? (times.isEmpty ? null : times.reduce(math.min));
  var endMs = sessionEndMs ?? (times.isEmpty ? null : times.reduce(math.max));
  if (startMs == null) return null;
  endMs ??= startMs;
  final gps = pts.where((p) => p[0].abs() <= 90 && p[1].abs() <= 180 && !(p[0] == 0 && p[1] == 0) && !p[0].isNaN).toList();
  var dist = distanceM ?? 0;
  if (dist <= 0 && gps.length > 1) {
    for (var i = 1; i < gps.length; i++) { dist += _hav(gps[i - 1][0], gps[i - 1][1], gps[i][0], gps[i][1]); }
  }
  final hrs = pts.where((p) => p.length > 4 && p[4] > 30 && p[4] < 250).toList();
  var guessed = false;
  var t = type;
  if (t == null) {
    guessed = true;
    final sec = (endMs - startMs) / 1000;
    final kmh = sec > 0 && dist > 200 ? dist / 1000 / (sec / 3600) : 0.0;
    t = gps.length < 2 ? 0 : kmh < 7 ? 79 : kmh <= 18 ? 56 : 8;
  }
  // keep ~1500 route points (small file, fast map)
  List<List<double>> route = gps;
  if (gps.length > 1500) {
    final step = (gps.length / 1500).ceil();
    route = [for (var i = 0; i < gps.length; i += step) gps[i]];
    if (route.last != gps.last) route.add(gps.last);
  }
  List<List<double>> hr = [for (final p in hrs) [p[3], p[4]]];
  if (hr.length > 2500) { final s = (hr.length / 2500).ceil(); hr = [for (var i = 0; i < hr.length; i += s) hr[i]]; }
  return {
    'type': t, 'guessed': guessed, 'title': title,
    'start': startMs.round(), 'end': endMs.round(),
    'distanceM': dist, 'kcal': kcal ?? 0.0,
    'hrAvg': hrs.isEmpty ? 0.0 : hrs.fold<double>(0, (a, p) => a + p[4]) / hrs.length,
    'hrMax': hrs.isEmpty ? 0.0 : hrs.map((p) => p[4]).reduce(math.max),
    'hrMin': hrs.isEmpty ? 0.0 : hrs.map((p) => p[4]).reduce(math.min),
    'route': [for (final p in route) [double.parse(p[0].toStringAsFixed(5)), double.parse(p[1].toStringAsFixed(5)), p[2].roundToDouble(), p[3].round()]],
    'hr': [for (final p in hr) [p[0].round(), p[1].round()]],
  };
}

// ── GPX ──
Map<String, dynamic>? _parseGpx(String x) {
  final trk = RegExp(r'<trk[ >].*?</trk>', dotAll: true).firstMatch(x)?.group(0) ?? x;
  final name = RegExp(r'<name>(.*?)</name>', dotAll: true).firstMatch(trk)?.group(1)?.trim() ?? '';
  final typeStr = RegExp(r'<type>(.*?)</type>', dotAll: true).firstMatch(trk)?.group(1)?.trim() ?? '';
  final cdata = RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true);
  String clean(String s) => (cdata.firstMatch(s)?.group(1) ?? s).replaceAll('&amp;', '&').replaceAll('&apos;', "'").replaceAll('&quot;', '"').trim();
  final pts = <List<double>>[];
  final rx = RegExp(r'<trkpt\s([^>]*)>(.*?)</trkpt>', dotAll: true);
  for (final m in rx.allMatches(x)) {
    final attrs = m.group(1)!, body = m.group(2)!;
    final lat = double.tryParse(RegExp(r'lat="([^"]+)"').firstMatch(attrs)?.group(1) ?? '');
    final lon = double.tryParse(RegExp(r'lon="([^"]+)"').firstMatch(attrs)?.group(1) ?? '');
    if (lat == null || lon == null) continue;
    final ele = double.tryParse(RegExp(r'<ele>([^<]+)</ele>').firstMatch(body)?.group(1) ?? '') ?? 0;
    final ts = RegExp(r'<time>([^<]+)</time>').firstMatch(body)?.group(1);
    final t = ts == null ? null : DateTime.tryParse(ts.trim());
    final hr = double.tryParse(RegExp(r'<(?:\w+:)?hr>(\d+)</').firstMatch(body)?.group(1) ?? '') ?? -1;
    pts.add([lat, lon, ele, t == null ? 0 : t.millisecondsSinceEpoch.toDouble(), hr]);
  }
  if (pts.length < 2) return null;
  var title = clean(name);
  if (pts.every((p) => p[3] == 0)) {
    final mt = RegExp(r'<metadata>.*?<time>([^<]+)</time>', dotAll: true).firstMatch(x)?.group(1);
    final d = mt == null ? null : DateTime.tryParse(mt.trim());
    if (d == null) return null; // no time at all: can't match it to a session
    for (final p in pts) { p[3] = d.millisecondsSinceEpoch.toDouble(); }
  }
  return _finish(pts: pts, type: _sportFromName(typeStr) ?? _sportFromName(title), title: title);
}

// ── FIT ──
class _Def { final bool little; final int gmn; final List<List<int>> fields; final int dev; _Def(this.little, this.gmn, this.fields, this.dev); int get size => fields.fold(0, (a, f) => a + f[1]) + dev; }

Map<String, dynamic>? _parseFit(Uint8List b) {
  if (b.length < 14) return null;
  final bd = ByteData.sublistView(b);
  final hs = b[0];
  final end = math.min(b.length - 2, hs + bd.getUint32(4, Endian.little));
  var pos = hs;
  final defs = <int, _Def>{};
  final pts = <List<double>>[];
  int lastTs = 0;
  int? sport, sub; double? sStart, sElapsed, sDist, sCal; String? name;
  const fitEpoch = 631065600;

  int? rd(int off, int size, int base, bool little) {
    final e = little ? Endian.little : Endian.big;
    final t = base & 0x1f;
    switch (size) {
      case 1: final v = b[off]; if (v == 0xFF && t != 1) return null; return t == 1 ? (v > 127 ? v - 256 : v) : v;
      case 2: { final v = bd.getUint16(off, e); if (v == 0xFFFF) return null; return t == 3 ? (v > 32767 ? v - 65536 : v) : v; }
      case 4: { final v = bd.getUint32(off, e); if (v == 0xFFFFFFFF) return null; return t == 5 ? (v > 0x7FFFFFFF ? v - 0x100000000 : v) : v; }
    }
    return null;
  }

  while (pos < end) {
    final h = b[pos++];
    int local; _Def? d;
    if (h & 0x80 != 0) {
      local = (h >> 5) & 3;
      final off = h & 0x1f;
      lastTs = (lastTs & ~0x1f) + off + (off < (lastTs & 0x1f) ? 32 : 0);
      d = defs[local];
      if (d == null) break;
    } else if (h & 0x40 != 0) {
      local = h & 0x0f;
      final hasDev = h & 0x20 != 0;
      pos++; // reserved
      final little = b[pos++] == 0;
      final gmn = bd.getUint16(pos, little ? Endian.little : Endian.big); pos += 2;
      final nf = b[pos++];
      final fields = <List<int>>[];
      for (var i = 0; i < nf; i++) { fields.add([b[pos], b[pos + 1], b[pos + 2]]); pos += 3; }
      var dev = 0;
      if (hasDev) { final nd = b[pos++]; for (var i = 0; i < nd; i++) { dev += b[pos + 1]; pos += 3; } }
      defs[local] = _Def(little, gmn, fields, dev);
      continue;
    } else {
      local = h & 0x0f;
      d = defs[local];
      if (d == null) break;
    }
    final start = pos;
    if (start + d.size > b.length) break;
    if (d.gmn == 20 || d.gmn == 18 || d.gmn == 21) {
      var off = start;
      double? lat, lon, alt, ts, hr; double? tsF;
      double? st, el, di, ca;
      for (final f in d.fields) {
        final fn = f[0], size = f[1], base = f[2];
        if (size == 1 || size == 2 || size == 4) {
          final v = rd(off, size, base, d.little);
          if (v != null) {
            if (d.gmn == 20) {
              switch (fn) {
                case 253: ts = v.toDouble(); case 0: lat = v * 180 / 2147483648; case 1: lon = v * 180 / 2147483648;
                case 2: alt ??= v / 5 - 500; case 78: alt = v / 5 - 500; case 3: hr = v.toDouble();
              }
            } else if (d.gmn == 18) {
              switch (fn) {
                case 2: st = v.toDouble(); case 7: el = v / 1000; case 9: di = v / 100; case 11: ca = v.toDouble();
                case 5: sport ??= v; case 6: sub ??= v;
              }
            }
          }
        }
        off += size;
      }
      if (h & 0x80 != 0 && d.gmn == 20) ts ??= lastTs.toDouble();
      if (d.gmn == 20) {
        if (ts != null) lastTs = ts.toInt();
        if (ts != null) { tsF = (ts + fitEpoch) * 1000; pts.add([lat ?? double.nan, lon ?? double.nan, alt ?? 0, tsF, hr ?? -1]); }
      } else if (d.gmn == 18) {
        sStart ??= st == null ? null : (st + fitEpoch) * 1000;
        sElapsed ??= el; sDist ??= di; sCal ??= ca;
      }
    }
    pos = start + d.size;
  }
  final gps = pts.where((p) => !p[0].isNaN).toList();
  final type = _sportFromFit(sport, sub);
  final sEnd = (sStart != null && sElapsed != null) ? sStart + sElapsed * 1000 : null;
  // all records (also without GPS) give start / end / heart rate
  final all = pts.map((p) => [p[0].isNaN ? 0.0 : p[0], p[1].isNaN ? 0.0 : p[1], p[2], p[3], p[4]]).toList();
  if (gps.isEmpty && all.length < 2 && sStart == null) return null;
  return _finish(pts: all, type: type, title: name ?? '', distanceM: sDist, kcal: sCal, sessionStartMs: sStart, sessionEndMs: sEnd);
}

// ── Public helpers for other sources (Intervals.icu…) ──
Map<String, dynamic>? buildActivity({required List<List<double>> pts, required int? type, required String title,
        double? distanceM, double? kcal, required double startMs, required double endMs}) =>
    _finish(pts: pts, type: type, title: title, distanceM: distanceM, kcal: kcal, sessionStartMs: startMs, sessionEndMs: endMs);
int? sportFromName(String s) => _sportFromName(s);
