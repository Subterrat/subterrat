/// 鼠群族群機制模型。
///
/// 參數來自公開文獻的概略範圍，未經臺北資料校準。
/// 這裡算出來的是示意情境，不是預測值，也不能用來決定實際投餌劑量或位置。
library;

class SimParams {
  /// 投藥週期（週）。0 表示不投藥。
  final int periodWeeks;

  /// 投餌強度：每次投餌時，在「中」食物豐度下會吃到致死劑量的族群比例。
  /// 這是覆蓋率的代理值，不是藥劑濃度。
  final double baseUptake;

  /// 每週從鄰近未處理區補進來的比例。
  final double migration;

  /// 資源充足時的每週成長率。
  final double growth;

  const SimParams({
    this.periodWeeks = 4,
    this.baseUptake = 0.6,
    this.migration = 0.10,
    this.growth = 0.15,
  });

  SimParams copyWith({
    int? periodWeeks,
    double? baseUptake,
    double? migration,
    double? growth,
  }) =>
      SimParams(
        periodWeeks: periodWeeks ?? this.periodWeeks,
        baseUptake: baseUptake ?? this.baseUptake,
        migration: migration ?? this.migration,
        growth: growth ?? this.growth,
      );
}

class SimResult {
  /// 每週族群數量。
  final List<double> population;

  /// 每週族群佔環境負載量的比例，0–1。地圖上色用這個。
  final List<double> ratio;

  /// 投餌發生的週次。
  final List<int> baitWeeks;

  const SimResult(this.population, this.ratio, this.baitWeeks);
}

class RatSim {
  static const int weeks = 130;

  /// 投藥從第幾週開始。前面留白是為了讓畫面看得到「投藥前」的基線。
  static const int startWeek = 26;

  /// 食物豐度的參考點。取食率以這個值為基準做調整。
  static const double kReference = 200;

  /// 天然食物與餌塊競爭的強度。
  static const double competition = 1.0;

  /// 食物越多，老鼠越不需要吃餌，取食率越低。
  /// 這是本模型的核心耦合，方向有文獻支持，曲率是簡化假設。
  static double effectiveUptake(double baseUptake, double carryingCapacity) {
    final v = baseUptake *
        (kReference * (1 + competition)) /
        (kReference + competition * carryingCapacity);
    return v > 0.95 ? 0.95 : v;
  }

  static SimResult run({
    required double carryingCapacity,
    required SimParams p,
  }) {
    final k = carryingCapacity <= 0 ? 1.0 : carryingCapacity;
    final uptake = effectiveUptake(p.baseUptake, k);

    var n = k;
    final pending = <int, double>{};
    final population = <double>[];
    final ratio = <double>[];
    final baitWeeks = <int>[];

    for (var t = 0; t < weeks; t++) {
      // 密度依賴的成長
      n += p.growth * n * (1 - n / k);

      // 投餌。抗凝血劑是延遲致死的，所以死亡排到後面兩週。
      if (p.periodWeeks > 0 &&
          t >= startWeek &&
          (t - startWeek) % p.periodWeeks == 0) {
        final poisoned = uptake * n;
        pending[t + 1] = (pending[t + 1] ?? 0) + poisoned * 0.6;
        pending[t + 2] = (pending[t + 2] ?? 0) + poisoned * 0.4;
        baitWeeks.add(t);
      }

      n -= pending[t] ?? 0;
      if (n < 0) n = 0;

      // 鄰近未處理區的再殖入
      if (k > n) n += p.migration * (k - n);

      population.add(n);
      ratio.add(n / k);
    }
    return SimResult(population, ratio, baitWeeks);
  }

  /// 最後 26 週的平均剩餘比例，用來排時程。
  static double steadyRatio({
    required double carryingCapacity,
    required SimParams p,
  }) {
    final r = run(carryingCapacity: carryingCapacity, p: p).ratio;
    var sum = 0.0;
    for (var i = weeks - 26; i < weeks; i++) {
      sum += r[i];
    }
    return sum / 26;
  }

  /// 投餌後，族群回升到門檻值所需的週數。
  ///
  /// 這是排回訪時機的依據：回升越快的地方越早需要再處理。
  /// 回傳 null 表示在模擬期間內都沒有回升到門檻。
  static int? weeksToRebound({
    required double carryingCapacity,
    required SimParams p,
    double threshold = 0.6,
  }) {
    final res = run(carryingCapacity: carryingCapacity, p: p);
    if (res.baitWeeks.isEmpty) return null;
    final first = res.baitWeeks.first;

    // 先等族群被壓下去，再看它多久爬回門檻。
    var trough = first;
    for (var t = first; t < weeks && t < first + 12; t++) {
      if (res.ratio[t] < res.ratio[trough]) trough = t;
    }
    for (var t = trough; t < weeks; t++) {
      if (res.ratio[t] >= threshold) return t - first;
    }
    return null;
  }
}
