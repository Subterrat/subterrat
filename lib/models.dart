import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 一個聚合網格。
///
/// 對外只暴露聚合後的格子，不含人孔、管段或精確店家位置。
class RiskCell {
  final String cellId;
  final String district;

  /// 格子的四個角（或六個角）。直接餵給 Polygon。
  final List<LatLng> corners;
  final LatLng center;

  /// T0 結構性分數，0–1。這是排序用的分數，不是機率。
  final double structuralScore;

  /// 環境負載量的相對刻度，主要由餐飲密度決定。
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
    this.topFactors = const [],
  });

  factory RiskCell.fromJson(Map<String, dynamic> j) {
    final pts = (j['corners'] as List)
        .map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
        .toList();
    return RiskCell(
      cellId: j['cell_id'] as String,
      district: (j['district'] ?? '') as String,
      corners: pts,
      center: LatLng(
        (j['lat'] as num).toDouble(),
        (j['lng'] as num).toDouble(),
      ),
      structuralScore: (j['score'] as num).toDouble(),
      carryingCapacity: (j['carrying_capacity'] as num?)?.toDouble() ?? 200,
      topFactors:
          ((j['top_factors'] as List?) ?? const []).map((e) => '$e').toList(),
    );
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
  off('隱藏', '只看預測');

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

  factory Provenance.fromJson(Map<String, dynamic> j) => Provenance(
        releaseId: '${j['release_id'] ?? 'unknown'}',
        freezeId: '${j['freeze_id'] ?? 'NOT_FROZEN'}',
        frozenAt: DateTime.tryParse('${j['frozen_at']}')?.toLocal(),
        t1Start: DateTime.tryParse('${j['t1_start']}')?.toLocal(),
        t1End: DateTime.tryParse('${j['t1_end']}')?.toLocal(),
        scoreSemantics:
            '${j['score_semantics'] ?? unfrozen.scoreSemantics}',
        policy: '${j['evidence_policy']}' == 'TRUSTED_RECEIPT'
            ? EvidencePolicy.trustedReceipt
            : EvidencePolicy.noTrustedResult,
        sources: ((j['sources'] as Map?) ?? const {})
            .map((k, v) => MapEntry('$k', '$v')),
      );
}

/// 一筆已觀測到的見鼠通報（來自見鼠雷達）。
///
/// 與 [CitizenReport] 是**不同的東西**：
/// 這是拿來驗證模型的 outcome，那是本 app 自己收到的通報。
/// 兩者不可混用，否則驗證會被自家資料污染。
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

/// 民眾通報的類型。
enum ReportKind {
  sighting('看到老鼠'),
  carcass('看到鼠屍'),
  burrow('看到鼠洞或鼠道'),
  droppings('看到鼠糞或咬痕');

  const ReportKind(this.label);
  final String label;
}

/// 一筆民眾通報。
///
/// 注意：這是我們自己 app 收到的通報，**不是**見鼠雷達的資料。
/// 兩者不可混在一起：見鼠雷達是驗證模型用的 outcome，
/// 自家通報若回灌進模型會造成自我強化，見 docs/HARNESS_ARCHITECTURE.md。
class CitizenReport {
  final String? id;
  final ReportKind kind;
  final LatLng location;
  final String note;
  final DateTime reportedAt;

  /// pending 表示還沒送出成功，會排隊等網路恢復。
  final bool pending;

  const CitizenReport({
    this.id,
    required this.kind,
    required this.location,
    required this.note,
    required this.reportedAt,
    this.pending = false,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'lat': location.latitude,
        'lng': location.longitude,
        'note': note,
        'reported_at': reportedAt.toUtc().toIso8601String(),
      };

  factory CitizenReport.fromJson(Map<String, dynamic> j) => CitizenReport(
        id: j['id'] as String?,
        kind: ReportKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => ReportKind.sighting,
        ),
        location: LatLng(
          (j['lat'] as num).toDouble(),
          (j['lng'] as num).toDouble(),
        ),
        note: (j['note'] ?? '') as String,
        reportedAt:
            DateTime.tryParse('${j['reported_at']}')?.toLocal() ?? DateTime.now(),
      );

  CitizenReport copyWith({String? id, bool? pending}) => CitizenReport(
        id: id ?? this.id,
        kind: kind,
        location: location,
        note: note,
        reportedAt: reportedAt,
        pending: pending ?? this.pending,
      );
}

/// 模擬情境下的一列回訪時機。
///
/// 這不是給市府的正式建議，是模擬結果的呈現。
class ScheduleRow {
  final RiskCell cell;

  /// 這個情境下的穩態剩餘族群比例，0–1。越高代表越壓不下去。
  final double steadyRatio;

  /// 投餌後回升到門檻所需週數。null 表示模擬期內沒回升。
  final int? reboundWeeks;

  const ScheduleRow({
    required this.cell,
    required this.steadyRatio,
    required this.reboundWeeks,
  });

  /// 排序用：回升越快、壓制效果越差的排前面。
  double get urgency {
    final r = reboundWeeks?.toDouble() ?? 999;
    return steadyRatio * 100 - r;
  }
}
