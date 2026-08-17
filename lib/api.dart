import 'dart:convert';
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// 資料來源。
///
/// 一律走 C 的 Cloud Run API，前端不直接連 BigQuery
/// （金鑰會被拆出來，而且改欄位時兩邊都要動）。
///
/// [baseUrl] 留空時會自動改用本機產生的示範格子，
/// 這樣後端還沒好之前你也能先把整個介面做完。
class RiskApi {
  RiskApi({this.baseUrl = ''});

  final String baseUrl;

  bool get isMock => baseUrl.isEmpty;

  /// [topN] 只取分數最高的前 N 格。整個臺北市切完約有九百多格，
  /// 全部畫上去地圖會掉幀，而且熱點圖本來就只需要顯示熱的地方。
  Future<List<RiskCell>> fetchCells({int topN = 380}) async {
    if (isMock) return _mockCells(topN);

    final uri = Uri.parse('$baseUrl/api/risk?top=$topN');
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('風險資料讀取失敗：HTTP ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final list = (body is Map ? body['cells'] : body) as List;
    return list
        .map((e) => RiskCell.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 讀取版本與封存資訊。
  ///
  /// 後端還沒提供時回傳「尚未封存」，畫面會照實顯示 NOT_FROZEN，
  /// 而不是留白假裝一切正常。
  Future<Provenance> fetchProvenance() async {
    if (isMock) return Provenance.unfrozen;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/provenance'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return Provenance.unfrozen;
      return Provenance.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    } catch (_) {
      return Provenance.unfrozen;
    }
  }

  /// 讀取已觀測到的見鼠通報，用來驗證模型圈選得準不準。
  ///
  /// 正式版應接見鼠雷達 CSV 清洗後的結果，並且只納入
  /// 臺北市範圍內、類型=鼠蹤、狀態=已通過審核、且落在鎖定觀測窗內的通報。
  Future<List<ObservedReport>> fetchObservedReports() async {
    if (isMock) return _mockObserved();
    final res = await http
        .get(Uri.parse('$baseUrl/api/observed'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final list = (body is Map ? body['reports'] : body) as List;
    return list
        .map((e) => ObservedReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 示範用的觀測通報。
  ///
  /// 刻意**不**照著模型分數生成，而是用食物密度加上大量雜訊，
  /// 再混入兩成完全隨機的點。否則畫面會假裝出一個漂亮的命中率，
  /// 那是在自欺欺人。接上真實資料前，畫面上的命中率沒有意義。
  List<ObservedReport> _mockObserved() {
    final rng = Random(77003);
    final out = <ObservedReport>[];
    final cells = _mockCells(380);

    for (var i = 0; i < 140; i++) {
      LatLng p;
      if (rng.nextDouble() < 0.2) {
        // 兩成純隨機，散在全市
        double lat, lng;
        do {
          lat = 24.960 + rng.nextDouble() * 0.252;
          lng = 121.450 + rng.nextDouble() * 0.216;
        } while (!_inTaipei(lat, lng));
        p = LatLng(lat, lng);
      } else {
        // 其餘依食物密度加權抽樣，再加上位置抖動
        final pick = cells[(pow(rng.nextDouble(), 1.7) * cells.length)
            .floor()
            .clamp(0, cells.length - 1)];
        p = LatLng(
          pick.center.latitude + (rng.nextDouble() - 0.5) * 0.006,
          pick.center.longitude + (rng.nextDouble() - 0.5) * 0.0068,
        );
      }
      out.add(ObservedReport(
        id: 'obs-${i.toString().padLeft(3, '0')}',
        location: p,
        observedAt: DateTime(2026, 7, 21)
            .add(Duration(days: rng.nextInt(28), hours: rng.nextInt(24))),
      ));
    }
    return out;
  }

  /// 送出一筆民眾通報。
  ///
  /// 後端還沒好時會直接回傳一筆帶本機 id 的紀錄，讓畫面照常運作。
  /// 這些通報**不可以**跟見鼠雷達的資料混在一起，也不可以回灌進模型
  /// （會造成自我強化），詳見 docs/HARNESS_ARCHITECTURE.md。
  Future<CitizenReport> submitReport(CitizenReport r) async {
    if (isMock) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return r.copyWith(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        pending: false,
      );
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/reports'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(r.toJson()),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('通報送出失敗：HTTP ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return CitizenReport.fromJson(body);
  }

  /// 讀回已送出的通報。
  Future<List<CitizenReport>> fetchReports() async {
    if (isMock) return const [];
    final res = await http
        .get(Uri.parse('$baseUrl/api/reports'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final list = (body is Map ? body['reports'] : body) as List;
    return list
        .map((e) => CitizenReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------
  // 以下只在 baseUrl 留空時使用。上台展示前務必接上真實 API，
  // 因為這些格子是程式產生的，不是臺北市的資料。
  // ---------------------------------------------------------------

  /// 12 個行政區的大致中心點，用來判斷格子屬於哪一區。
  static const _districts = <(String, double, double)>[
    ('北投區', 25.132, 121.501),
    ('士林區', 25.096, 121.526),
    ('內湖區', 25.069, 121.594),
    ('南港區', 25.038, 121.607),
    ('松山區', 25.058, 121.558),
    ('中山區', 25.064, 121.533),
    ('大同區', 25.063, 121.513),
    ('萬華區', 25.028, 121.499),
    ('中正區', 25.032, 121.518),
    ('大安區', 25.026, 121.543),
    ('信義區', 25.031, 121.571),
    ('文山區', 24.989, 121.570),
  ];

  /// 臺北市邊界的粗略輪廓。
  ///
  /// 這是手繪的近似值，只是為了讓示範格子不要蓋到新北市和山區。
  /// 正式版請改用 data.taipei 的行政區界圖資。
  static const _boundary = <(double, double)>[
    (25.190, 121.495), (25.205, 121.548), (25.168, 121.598),
    (25.100, 121.618), (25.070, 121.648), (25.040, 121.658),
    (24.999, 121.628), (24.966, 121.590), (24.962, 121.552),
    (24.985, 121.528), (25.005, 121.508), (25.028, 121.492),
    (25.070, 121.478), (25.110, 121.470), (25.150, 121.468),
  ];

  /// 商業與夜市聚集點。餐飲密度以這些點為中心向外遞減，
  /// 這樣熱點會是多中心的，比單一同心圓真實。
  static const _cores = <(double, double, double)>[
    (25.048, 121.517, 1.00), // 臺北車站
    (25.042, 121.544, 0.95), // 忠孝復興一帶
    (25.033, 121.565, 0.90), // 信義計畫區
    (25.035, 121.500, 0.85), // 龍山寺、華西街
    (25.088, 121.524, 0.80), // 士林夜市
    (25.015, 121.534, 0.70), // 公館
    (25.079, 121.575, 0.65), // 內湖科技園區
    (25.061, 121.538, 0.60), // 中山雙連
    (25.132, 121.501, 0.45), // 北投
    (24.989, 121.570, 0.45), // 木柵
  ];

  static bool _inTaipei(double lat, double lng) {
    var inside = false;
    for (var i = 0, j = _boundary.length - 1; i < _boundary.length; j = i++) {
      final (yi, xi) = _boundary[i];
      final (yj, xj) = _boundary[j];
      if ((yi > lat) != (yj > lat) &&
          lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  List<RiskCell> _mockCells(int n) {
    // 固定亂數種子，讓每次啟動看到的畫面一致，方便反覆排練。
    final rng = Random(20260817);

    // 涵蓋整個臺北市的經緯度範圍。
    const minLat = 24.960, maxLat = 25.212;
    const minLng = 121.450, maxLng = 121.666;

    // 約 600 公尺見方。再細下去格子數會讓地圖掉幀。
    const dLat = 0.0054;
    const dLng = 0.0060;

    final cells = <RiskCell>[];
    var id = 0;
    for (var lat = minLat; lat <= maxLat; lat += dLat) {
      for (var lng = minLng; lng <= maxLng; lng += dLng) {
        if (!_inTaipei(lat, lng)) continue;

        // 各商業核心的高斯貢獻加總，形成多中心的密度分布。
        var food = 45.0;
        for (final (clat, clng, w) in _cores) {
          final dy = (lat - clat) * 111.0;
          final dx = (lng - clng) * 100.9;
          final d2 = dy * dy + dx * dx;
          food += 430 * w * exp(-d2 / 5.2);
        }
        food = (food + rng.nextDouble() * 55).clamp(45.0, 500.0);

        // 雜訊只留 6%。給太多的話山區會被隨機數推進前段，
        // 熱點圖就會變成整片都亮，看不出哪裡才是熱點。
        final score =
            ((food - 45) / 455 * 0.94 + rng.nextDouble() * 0.06).clamp(0.0, 1.0);

        var best = _districts.first;
        var bestD = double.infinity;
        for (final d in _districts) {
          final dy = lat - d.$2, dx = lng - d.$3;
          final dd = dy * dy + dx * dx;
          if (dd < bestD) {
            bestD = dd;
            best = d;
          }
        }

        final h = dLat / 2, w = dLng / 2;
        cells.add(RiskCell(
          cellId: 'demo-${(id++).toString().padLeft(4, '0')}',
          district: best.$1,
          center: LatLng(lat, lng),
          corners: [
            LatLng(lat - h, lng - w),
            LatLng(lat - h, lng + w),
            LatLng(lat + h, lng + w),
            LatLng(lat + h, lng - w),
          ],
          structuralScore: score,
          carryingCapacity: food,
          topFactors: [
            '餐飲密度 ${food.round()}',
            '鄰近市場 ${(rng.nextDouble() * 400 + 60).round()} m',
            '管線密度 ${(rng.nextDouble() * 40 + 10).round()}',
          ],
        ));
      }
    }

    cells.sort((a, b) => b.structuralScore.compareTo(a.structuralScore));
    return cells.take(n).toList();
  }
}
