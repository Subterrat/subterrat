import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 12 個行政區的大致中心點，用最近中心點法把座標分派到行政區。
/// mock 格子與真實 API 回傳的格子共用同一套判斷——後端的
/// `map_hotspot_cells_t0` 沒有行政區欄位，這只是顯示用途，
/// 不是精確的行政區界圖資。
const _districtCentroids = <(String, double, double)>[
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

String districtFor(LatLng p) {
  var best = _districtCentroids.first;
  var bestD = double.infinity;
  for (final d in _districtCentroids) {
    final dy = p.latitude - d.$2, dx = p.longitude - d.$3;
    final dd = dy * dy + dx * dx;
    if (dd < bestD) {
      bestD = dd;
      best = d;
    }
  }
  return best.$1;
}

/// 一個聚合網格。
///
/// 對外只暴露聚合後的格子，不含人孔、管段或精確店家位置。
class RiskCell {
  final String cellId;
  final String district;

  /// 格子的四個角（或六個角）。直接餵給 Polygon。
  final List<LatLng> corners;
  final LatLng center;

  /// T0 結構性分數，0–1，這是排序用的分數，不是機率。
  ///
  /// 目前真實資料一律是 null：`MainScore` 要 food／sewer／abandoned
  /// 三組 component 都到位才能合成，但「廢棄建築」還沒有 citywide
  /// 排名資料，後端不會為了湊一個總分而造假（見
  /// docs/API_CONTRACT.md 的 `MAIN_SCORE_NOT_COMPUTED_MISSING_ABANDONED_GROUP`）。
  /// 顯示層要把 null 當成「尚未可用」，不能當 0 分處理。
  final double? structuralScore;

  /// 餐飲密度分位（0–1 rank percentile）。目前唯二有值的 component 之一。
  final double? foodScore;

  /// 地下水道環境分位（0–1 rank percentile）。
  final double? sewerScore;

  /// 環境負載量的相對刻度，餵給 [lib/sim.dart] 的族群模擬用。
  /// 沒有對應的真實量測欄位，缺 structuralScore 時由 [foodScore]／
  /// [sewerScore] 換算成同一量級，純粹是模擬情境的輸入，不是承載量估計。
  final double carryingCapacity;

  /// 分數的主要成因，給側邊欄顯示。
  final List<String> topFactors;

  const RiskCell({
    required this.cellId,
    required this.district,
    required this.corners,
    required this.center,
    required this.structuralScore,
    required this.carryingCapacity,
    this.foodScore,
    this.sewerScore,
    this.topFactors = const [],
  });

  /// 排序／地圖上色深淺用的分數。有 [structuralScore] 就直接用；
  /// 沒有時退回可得 component 的平均值，只用來決定顯示順序與深淺，
  /// **不代表通過驗證的綜合結構分數**——那個欄位就是 [structuralScore]，
  /// 該是 null 就顯示 null。
  double get rankScore {
    final s = structuralScore;
    if (s != null) return s;
    final parts = [foodScore, sewerScore].whereType<double>().toList();
    if (parts.isEmpty) return 0;
    return parts.reduce((a, b) => a + b) / parts.length;
  }

  /// 從 `GET /api/v1/releases/{release_id}/cells` 的一個 GeoJSON Feature
  /// 建立格子。欄位對照見 docs/API_CONTRACT.md 與
  /// services/hotspot_api/schemas/cells.py 的 `CellFeature`。
  factory RiskCell.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final corners = _exteriorRing(geometry);
    final center = _centroid(corners);
    final props = feature['properties'] as Map<String, dynamic>;
    final components = (props['components'] as Map?) ?? const {};
    final food = (components['food'] as num?)?.toDouble();
    final sewer = (components['sewer'] as num?)?.toDouble();
    final raw = (props['raw_layer_fields'] as Map?) ?? const {};
    final coverageState =
        props['coverage_state'] as String? ?? 'unscored_missing_group';

    final factors = <String>[];
    if (food != null) factors.add('餐飲密度分位 ${(food * 100).round()}%');
    if (sewer != null) factors.add('污水管線分位 ${(sewer * 100).round()}%');
    if (raw['food_top_area'] == true) factors.add('位於高餐飲密度熱區');
    if (raw['sewer_top_area'] == true) factors.add('位於高污水風險熱區');
    if (coverageState == 'unscored_missing_group') {
      factors.add('缺廢棄建築分項，尚無綜合結構分數');
    }

    return RiskCell(
      cellId: props['cell_id'] as String? ?? '${feature['id']}',
      district: districtFor(center),
      corners: corners,
      center: center,
      structuralScore: (props['structural_score'] as num?)?.toDouble(),
      foodScore: food,
      sewerScore: sewer,
      carryingCapacity: _carryingCapacityFrom(food, sewer),
      topFactors: factors,
    );
  }

  static double _carryingCapacityFrom(double? food, double? sewer) {
    final parts = [food, sewer].whereType<double>().toList();
    final avg = parts.isEmpty ? 0.5 : parts.reduce((a, b) => a + b) / parts.length;
    return 45 + avg.clamp(0.0, 1.0) * 455;
  }

  /// GeoJSON 座標順序固定是 `[經度, 緯度]`（見 API_CONTRACT.md 5.1）。
  /// MultiPolygon 只取第一個 polygon 的外環——地圖上每格只需要畫一個
  /// Polygon，不需要精確重現洞或多塊幾何。
  static List<LatLng> _exteriorRing(Map<String, dynamic> geometry) {
    final coordinates = geometry['coordinates'] as List;
    final ring = geometry['type'] == 'MultiPolygon'
        ? (coordinates.first as List).first as List
        : coordinates.first as List;
    final points = ring
        .map((p) => LatLng(
              ((p as List)[1] as num).toDouble(),
              (p[0] as num).toDouble(),
            ))
        .toList();
    // GeoJSON ring 首尾點相同（閉合環），畫 Polygon 不需要重複的收尾點。
    if (points.length > 1 && points.first == points.last) {
      points.removeLast();
    }
    return points;
  }

  static LatLng _centroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    var lat = 0.0, lng = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }
}

/// 觀測通報在地圖上的呈現方式。
///
/// 兩種各有適用場合，所以都留著：
/// - [points] 數得出命中率，而且誠實表示這是一筆一筆的離散通報
/// - [density] 視覺衝擊強，適合簡報首頁，但看不出命中與否
///
/// 密度模式刻意用**紫色**而不是紅色。預測範圍是橘色，紅橘同屬暖色，
/// 疊在一起時「答案所在的重疊區」會糊成一片，那正好是最該看清楚的地方。
enum ObservedDisplay {
  points('點狀', '綠=命中　粉=未命中'),
  density('密度', '看整體分布，數不出命中率'),
  off('隱藏', '只看圈選範圍');

  const ObservedDisplay(this.label, this.hint);
  final String label;
  final String hint;
}

/// 證據政策狀態。
///
/// 對應 AGENTS.md：目前沒有 repository-owned Sensor 或 validation receipt，
/// 因此不得宣稱 TRUSTED_RECEIPT，一律回報 NO_TRUSTED_RESULT。
enum EvidencePolicy {
  noTrustedResult(
    'NO_TRUSTED_RESULT',
    '尚無可信驗證收據',
    '這個版本沒有任何自動化 Sensor 產生的驗證收據。畫面上的分數與命中率都是'
        '未經獨立驗證的計算結果，不能當成已驗證的結論引用。',
  ),
  trustedReceipt(
    'TRUSTED_RECEIPT',
    '已有驗證收據',
    '已由 Sensor 產生驗證收據。',
  );

  const EvidencePolicy(this.code, this.label, this.detail);
  final String code;
  final String label;
  final String detail;
}

/// 版本與封存來源資訊。
///
/// 這一整組是為了讓畫面上的任何數字都能被追溯到
/// 「哪一版程式、哪一份封存、什麼時候凍結的」。
class Provenance {
  /// 這一版前端／模型的發布代號。
  final String releaseId;

  /// T0 封存的識別碼，通常是封存檔內容的雜湊。
  final String freezeId;

  /// 封存時間。之後任何特徵、權重、網格、K 值都不得再改。
  final DateTime? frozenAt;

  /// 觀測窗起訖。
  final DateTime? t1Start;
  final DateTime? t1End;

  /// 分數的語意說明。**不可以稱為機率。**
  final String scoreSemantics;

  final EvidencePolicy policy;

  /// 各資料來源的版本標記，例如見鼠雷達 CSV 的擷取時間與雜湊。
  final Map<String, String> sources;

  const Provenance({
    required this.releaseId,
    required this.freezeId,
    this.frozenAt,
    this.t1Start,
    this.t1End,
    required this.scoreSemantics,
    this.policy = EvidencePolicy.noTrustedResult,
    this.sources = const {},
  });

  /// 還沒封存時用的預設值。畫面必須明確顯示「尚未封存」而不是留白。
  static const unfrozen = Provenance(
    releaseId: 'dev-local',
    freezeId: 'NOT_FROZEN',
    scoreSemantics: '結構性見鼠通報熱點篩選分數（0–1 排序用，非機率）',
  );

  bool get isFrozen => freezeId != 'NOT_FROZEN' && freezeId.isNotEmpty;
}

/// 一筆已觀測到的見鼠通報（來自見鼠雷達）。
///
/// 這是拿來驗證模型的 outcome，見 docs/HARNESS_ARCHITECTURE.md。
class ObservedReport {
  final String id;
  final LatLng location;
  final DateTime observedAt;

  /// 是否落在模型圈選的高分格子裡。null 表示還沒判定。
  final bool? insideTopK;

  const ObservedReport({
    required this.id,
    required this.location,
    required this.observedAt,
    this.insideTopK,
  });

  ObservedReport withHit(bool hit) => ObservedReport(
        id: id,
        location: location,
        observedAt: observedAt,
        insideTopK: hit,
      );

  factory ObservedReport.fromJson(Map<String, dynamic> j) => ObservedReport(
        id: '${j['id']}',
        location: LatLng(
          (j['lat'] as num).toDouble(),
          (j['lng'] as num).toDouble(),
        ),
        observedAt:
            DateTime.tryParse('${j['observed_at']}')?.toLocal() ?? DateTime.now(),
      );
}

