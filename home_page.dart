import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'api.dart';
import 'models.dart';
import 'sim.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api});

  final RiskApi api;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<RiskCell> _cells = const [];
  final Map<String, SimResult> _sims = {};
  final List<CitizenReport> _reports = [];
  List<ObservedReport> _observed = const [];
  SimParams _params = const SimParams();

  /// 觀測通報的呈現方式。純顯示切換，不是權限。
  ObservedDisplay _obsMode = ObservedDisplay.points;

  /// 版本與封存資訊。後端沒提供時是「尚未封存」。
  Provenance _prov = Provenance.unfrozen;

  GoogleMapController? _map;

  /// 資料資訊面板是否展開。
  bool _infoOpen = false;

  /// 圓形不確定範圍的文字標籤，key 是格子 id。
  final Map<String, BitmapDescriptor> _labelIcons = {};

  /// 時間軸的起算日。第 [RatSim.startWeek] 週對應這一天。
  static final DateTime _t0Date = DateTime(2026, 8, 18);

  /// 目前週次對應的實際日期。
  DateTime get _weekDate =>
      _t0Date.add(Duration(days: (_week - RatSim.startWeek) * 7));

  /// 需要提醒的事項數：待送出的通報 + 落在圈選外的觀測通報。
  int get _alertCount =>
      _reports.where((r) => r.pending).length +
      (_observed.isEmpty ? 0 : (_observed.length - _hits) > 0 ? 1 : 0);

  /// 圈選比例。這個值必須事先定死並寫進封存檔，事後調整就是作弊。
  static const double kTopFraction = 0.10;

  int _week = RatSim.startWeek + 2;
  Timer? _ticker;
  RiskCell? _selected;
  /// 臺北市大致中心，縮放到能看到 12 個行政區。
  LatLng _mapCenter = const LatLng(25.0750, 121.5560);
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cells = await widget.api.fetchCells();
      final reports = await widget.api.fetchReports();
      final observed = await widget.api.fetchObservedReports();
      final prov = await widget.api.fetchProvenance();
      setState(() {
        _prov = prov;
        _cells = cells;
        _reports
          ..clear()
          ..addAll(reports);
        _observed = _markHits(observed, cells);
        _loading = false;
      });
      _recompute();
      unawaited(_buildLabels());
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// 參數變動時重跑所有格子的模擬，結果快取起來。
  /// 拖時間軸時只是查表，不重算，這樣動畫才不會卡。
  void _recompute() {
    _sims.clear();
    for (final c in _cells) {
      _sims[c.cellId] =
          RatSim.run(carryingCapacity: c.carryingCapacity, p: _params);
    }
    setState(() {});
  }

  void _setParams(SimParams p) {
    _params = p;
    _recompute();
  }

  void _togglePlay() {
    if (_ticker != null) {
      _ticker!.cancel();
      setState(() => _ticker = null);
      return;
    }
    setState(() {
      _ticker = Timer.periodic(const Duration(milliseconds: 260), (_) {
        setState(() {
          _week = _week >= RatSim.weeks - 1 ? RatSim.startWeek : _week + 1;
        });
      });
    });
  }

  /// 這一格此刻的熱點強度。
  ///
  /// 結構性風險 × 模擬剩餘族群：地點本身多容易有老鼠，
  /// 乘上這個時間點被壓制到什麼程度。兩者相乘才是「現在這裡有多熱」。
  double _heat(RiskCell c) {
    final sim = _sims[c.cellId];
    if (sim == null) return c.structuralScore;
    return c.structuralScore * sim.ratio[_week];
  }

  Set<Polygon> _polygons() {
    final out = <Polygon>{};
    final k = _topKCount;
    for (var i = 0; i < _cells.length; i++) {
      final c = _cells[i];
      final v = _heat(c);
      final fill = Palette.heatFill(v);
      final isSel = _selected?.cellId == c.cellId;
      final isTopK = i < k;
      // 低於門檻的格子整個不畫，否則整片會連成一塊實心色塊。
      if (fill.a == 0 && !isSel && !isTopK) continue;
      out.add(Polygon(
        polygonId: PolygonId(c.cellId),
        points: c.corners,
        fillColor: fill,
        // 圈選的格子描邊，讓「我們事先指出的地方」在圖上看得見。
        strokeColor: isSel
            ? Palette.accent
            : (isTopK ? const Color(0xAA78240F) : const Color(0x00000000)),
        strokeWidth: isSel ? 3 : (isTopK ? 1 : 0),
        consumeTapEvents: true,
        onTap: () => setState(() => _selected = c),
      ));
    }
    return out;
  }

  /// 分數最高的前 K 比例格子。api 回傳時已依分數排序。
  int get _topKCount => (_cells.length * kTopFraction).round().clamp(1, 9999);

  /// 判定每一筆觀測通報有沒有落在圈選的格子裡。
  ///
  /// 這就是 Capture@K 的分子。格子是軸對齊矩形，所以直接比邊界即可。
  static List<ObservedReport> _markHits(
      List<ObservedReport> obs, List<RiskCell> cells) {
    final k = (cells.length * kTopFraction).round().clamp(1, cells.length);
    final top = cells.take(k).toList();
    return obs.map((o) {
      var hit = false;
      for (final c in top) {
        var minLat = double.infinity, maxLat = -double.infinity;
        var minLng = double.infinity, maxLng = -double.infinity;
        for (final p in c.corners) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }
        if (o.location.latitude >= minLat &&
            o.location.latitude <= maxLat &&
            o.location.longitude >= minLng &&
            o.location.longitude <= maxLng) {
          hit = true;
          break;
        }
      }
      return o.withHit(hit);
    }).toList();
  }

  int get _hits => _observed.where((o) => o.insideTopK == true).length;

  double get _captureAtK =>
      _observed.isEmpty ? 0 : _hits / _observed.length;

  /// 結構性分數最高的前三格，用來畫圓形不確定範圍。
  ///
  /// 用結構性分數而不是當下熱度，是為了讓圈選範圍在播放時間軸時
  /// **固定不動**。圈選代表「我們事先指出的地方」，它不該隨動畫跳來跳去。
  List<RiskCell> _topHotspots() => _cells.take(3).toList();

  /// 圓形不確定範圍。
  ///
  /// 半徑代表「我們對位置的把握程度」，不是老鼠的活動範圍。
  /// 排名越後面的熱點畫得越大，表示位置越不確定。
  Set<Circle> _circles() {
    final out = <Circle>{};
    final tops = _topHotspots();
    for (var i = 0; i < tops.length; i++) {
      out.add(Circle(
        circleId: CircleId('unc-${tops[i].cellId}'),
        center: tops[i].center,
        radius: 700.0 + i * 190,
        fillColor: Palette.uncertainty.withValues(alpha: 0.16),
        strokeColor: Palette.uncertaintyEdge,
        strokeWidth: 2,
      ));
    }

    // 密度模式：每筆通報畫一個大範圍的半透明圓，重疊處自然加深，
    // 形成類似熱力圖的效果。google_maps_flutter 沒有內建熱力圖層，
    // 這是能在原生元件上做到、又不必後端預先算圖磚的做法。
    if (_obsMode == ObservedDisplay.density) {
      for (final o in _observed) {
        out.add(Circle(
          circleId: CircleId('den-${o.id}'),
          center: o.location,
          radius: 380,
          fillColor: Palette.observedDensity.withValues(alpha: 0.11),
          strokeWidth: 0,
        ));
      }
    }
    return out;
  }

  /// 把標籤文字畫成圖片，才能當成地圖標記顯示。
  /// google_maps_flutter 沒辦法直接在圖上放文字。
  Future<BitmapDescriptor> _labelBitmap(String text) async {
    const scale = 3.0;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 11 * scale,
          fontWeight: FontWeight.w700,
          color: Palette.uncertaintyInk,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padX = 7 * scale, padY = 4 * scale;
    final w = tp.width + padX * 2, h = tp.height + padY * 2;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h), Radius.circular(6 * scale));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xEBFFFFFF));
    canvas.drawRRect(
        rrect,
        Paint()
          ..color = Palette.uncertaintyEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * scale);
    tp.paint(canvas, Offset(padX, padY));

    final img = await rec.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// 為前三名熱點準備標籤圖片。畫好才 setState，避免地圖閃爍。
  Future<void> _buildLabels() async {
    final tops = _topHotspots();
    const names = ['高風險範圍', '較高風險範圍', '較高風險範圍'];
    final made = <String, BitmapDescriptor>{};
    for (var i = 0; i < tops.length; i++) {
      made[tops[i].cellId] = await _labelBitmap(names[i]);
    }
    if (!mounted) return;
    setState(() {
      _labelIcons
        ..clear()
        ..addAll(made);
    });
  }

  Set<Marker> _markers() {
    final out = <Marker>{};

    // 圓形範圍的文字標籤
    for (final c in _topHotspots()) {
      final icon = _labelIcons[c.cellId];
      if (icon == null) continue;
      out.add(Marker(
        markerId: MarkerId('lbl-${c.cellId}'),
        position: c.center,
        icon: icon,
        anchor: const Offset(0.5, 2.6),
        consumeTapEvents: true,
        onTap: () => setState(() => _selected = c),
      ));
    }

    if (_obsMode == ObservedDisplay.points) {
      for (final o in _observed) {
        final hit = o.insideTopK == true;
        out.add(Marker(
          markerId: MarkerId(o.id),
          position: o.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            hit ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRose,
          ),
          infoWindow: InfoWindow(
            title: hit ? '落在圈選範圍內' : '圈選範圍外',
            snippet: '見鼠通報　${_fmtTime(o.observedAt)}',
          ),
        ));
      }
    }

    for (var i = 0; i < _reports.length; i++) {
      final r = _reports[i];
      out.add(Marker(
        markerId: MarkerId(r.id ?? 'r$i'),
        position: r.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          r.pending ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(
          title: r.kind.label,
          snippet: r.note.isEmpty ? _fmtTime(r.reportedAt) : r.note,
        ),
      ));
    }
    return out;
  }

  List<ScheduleRow> _schedule() {
    final rows = _cells
        .map((c) => ScheduleRow(
              cell: c,
              steadyRatio: RatSim.steadyRatio(
                  carryingCapacity: c.carryingCapacity, p: _params),
              reboundWeeks: RatSim.weeksToRebound(
                  carryingCapacity: c.carryingCapacity, p: _params),
            ))
        .toList();
    rows.sort((a, b) => b.urgency.compareTo(a.urgency));
    return rows.take(25).toList();
  }

  // -------------------------------------------------------------------
  // 民眾通報
  // -------------------------------------------------------------------

  Future<void> _openReportSheet() async {
    var kind = ReportKind.sighting;
    final noteCtl = TextEditingController();
    final at = _mapCenter;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('回報你看到的狀況',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                '位置取畫面中央：${at.latitude.toStringAsFixed(5)}, '
                '${at.longitude.toStringAsFixed(5)}\n'
                '關掉這張表、移動地圖，再按一次通報鈕就能改位置。',
                style: const TextStyle(fontSize: 12, color: Palette.inkFaint),
              ),
              const SizedBox(height: 14),
              const Text('看到什麼',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReportKind.values
                    .map((k) => ChoiceChip(
                          label: Text(k.label),
                          selected: kind == k,
                          onSelected: (_) => setSheet(() => kind = k),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteCtl,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: '補充說明（可不填）',
                  hintText: '例如：從水溝蓋鑽進去，灰色，大概成年鼠',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(
                    '送出的內容會標為本 app 的通報，與見鼠雷達的資料分開存放。',
                    style: TextStyle(fontSize: 11, color: Palette.inkFaint),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('送出')),
              ]),
            ],
          ),
        ),
      ),
    );

    if (ok != true) {
      noteCtl.dispose();
      return;
    }

    final draft = CitizenReport(
      kind: kind,
      location: at,
      note: noteCtl.text.trim(),
      reportedAt: DateTime.now(),
      pending: true,
    );
    noteCtl.dispose();
    setState(() => _reports.insert(0, draft));

    try {
      final saved = await widget.api.submitReport(draft);
      if (!mounted) return;
      setState(() {
        final i = _reports.indexOf(draft);
        if (i >= 0) _reports[i] = saved;
      });
      _toast('通報已送出，謝謝');
    } catch (e) {
      if (!mounted) return;
      _toast('送不出去，先留在待送清單：$e');
    }
  }

  void _showAlerts() {
    final pending = _reports.where((r) => r.pending).length;
    final misses = _observed.isEmpty ? 0 : _observed.length - _hits;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('待處理事項'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.schedule, color: Palette.danger),
            title: Text('$pending 筆通報還沒送出'),
            subtitle: const Text('網路恢復後會自動重試'),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.location_off, color: Palette.miss),
            title: Text('$misses 筆通報落在圈選範圍外'),
            subtitle: const Text('這些是模型沒有預測到的地方，值得檢視'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉')),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _fmtTime(DateTime t) =>
      '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off, size: 40, color: Palette.inkFaint),
              const SizedBox(height: 12),
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('重試')),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openReportSheet,
        backgroundColor: Palette.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined, size: 21),
        label: const Text('通報鼠蹤',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(children: [
          _StatusBar(prov: _prov),
          Expanded(child: _buildMap()),
          _TimeBar(
            week: _week,
            baitWeeks:
                _sims.values.isEmpty ? const [] : _sims.values.first.baitWeeks,
            playing: _ticker != null,
            onWeek: (w) => setState(() => _week = w),
            onPlay: _togglePlay,
          ),
          SizedBox(
            height: 268,
            child: DefaultTabController(
              length: 3,
              child: Column(children: [
                ColoredBox(
                  color: Palette.surface,
                  child: TabBar(
                    labelColor: Palette.accent,
                    unselectedLabelColor: Palette.inkFaint,
                    indicatorColor: Palette.accent,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    tabs: [
                      const Tab(text: '投藥情境'),
                      const Tab(text: '回訪時機'),
                      Tab(text: '民眾通報 ${_reports.isEmpty ? "" : _reports.length}'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [
                    _ScenarioTab(params: _params, onChanged: _setParams),
                    _ScheduleTab(
                      rows: _schedule(),
                      onTap: (c) => setState(() => _selected = c),
                    ),
                    _ReportsTab(reports: _reports, onAdd: _openReportSheet),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMap() {
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: _mapCenter, zoom: 11.2),
        // 需要 google_maps_flutter 2.7 以上。舊版請改用
        // onMapCreated: (c) => c.setMapStyle(kMutedMapStyle)
        style: kMutedMapStyle,
        polygons: _polygons(),
        circles: _circles(),
        markers: _markers(),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        onMapCreated: (c) => _map = c,
        onCameraMove: (pos) => _mapCenter = pos.target,
        onTap: (_) => setState(() => _selected = null),
      ),
      // 通報時取畫面中央，所以要有個準心讓人知道會標在哪。
      const IgnorePointer(
        child: Center(
          child: Icon(Icons.add, size: 22, color: Color(0x66000000)),
        ),
      ),
      // 左上：品牌 + 週次
      Positioned(
        left: 12,
        top: 12,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _BrandMark(),
          const SizedBox(height: 8),
          _WeekBadge(week: _week, date: _weekDate),
          if (_selected != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 236,
              child: _CellCard(
                cell: _selected!,
                heat: _heat(_selected!),
                onClose: () => setState(() => _selected = null),
              ),
            ),
          ],
        ]),
      ),

      // 右上：資料資訊 + 通知
      Positioned(
        right: 12,
        top: 12,
        child: Row(children: [
          _IconBtn(
            icon: Icons.info_outline,
            filled: true,
            tooltip: '資料資訊',
            onTap: () => setState(() => _infoOpen = !_infoOpen),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.notifications_none,
            badge: _alertCount,
            tooltip: '待處理事項',
            onTap: () => _showAlerts(),
          ),
        ]),
      ),

      // 右側：縮放
      Positioned(
        right: 12,
        top: 66,
        child: _ZoomControls(
          onIn: () => _map?.animateCamera(CameraUpdate.zoomIn()),
          onOut: () => _map?.animateCamera(CameraUpdate.zoomOut()),
        ),
      ),

      if (_infoOpen)
        Positioned(
          right: 12,
          top: 66,
          width: 320,
          child: _DataInfoPanel(
            prov: _prov,
            onClose: () => setState(() => _infoOpen = false),
          ),
        ),

      const Positioned(left: 12, bottom: 44, child: _Legend()),

      // 底部中央：一句話說明圖上的顏色
      Positioned(
        left: 0,
        right: 0,
        bottom: 12,
        child: Center(child: _LegendPill(mode: _obsMode)),
      ),

      Positioned(
        right: 12,
        bottom: 44,
        child: _VerifyPanel(
          mode: _obsMode,
          hits: _hits,
          total: _observed.length,
          capture: _captureAtK,
          topKPercent: (kTopFraction * 100).round(),
          isMock: widget.api.isMock,
          onMode: (m) => setState(() => _obsMode = m),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------

/// 頂端狀態列：版本、封存代號、證據政策。
///
/// 這一條讓畫面上的任何數字都能被追溯到哪一版程式、哪一份封存。
/// NO_TRUSTED_RESULT 必須明講而不是省略 —— 沒有驗證收據就是沒有，
/// 留白會讓人誤以為已經驗證過。
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.prov});

  final Provenance prov;

  static String _d(DateTime? t) => t == null
      ? '—'
      : '${t.year}/${t.month.toString().padLeft(2, '0')}/'
          '${t.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final untrusted = prov.policy == EvidencePolicy.noTrustedResult;
    return Material(
      color: const Color(0xFFF7EDE4),
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              color: untrusted ? Palette.danger : Palette.accent,
              child: Text(prov.policy.code,
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'release ${prov.releaseId}　·　freeze '
                '${prov.isFrozen ? prov.freezeId : "尚未封存"}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: kMonoFamily,
                    fontSize: 11.5,
                    color: Palette.inkSoft),
              ),
            ),
            const Text('詳情',
                style: TextStyle(
                    fontSize: 11.5,
                    color: Palette.danger,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('版本與證據狀態'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('release_id', prov.releaseId),
              _row('freeze_id', prov.isFrozen ? prov.freezeId : 'NOT_FROZEN'),
              _row('封存時間', _d(prov.frozenAt)),
              _row('觀測窗', '${_d(prov.t1Start)} – ${_d(prov.t1End)}'),
              const Divider(height: 20),
              const Text('分數語意',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(prov.scoreSemantics,
                  style: const TextStyle(
                      fontSize: 12.8, color: Palette.inkSoft, height: 1.5)),
              const SizedBox(height: 6),
              const Text('這個分數是排序用的，不是機率。不可以說「這裡有 N% 機率有鼠患」。',
                  style: TextStyle(
                      fontSize: 12,
                      color: Palette.danger,
                      height: 1.5,
                      fontWeight: FontWeight.w600)),
              const Divider(height: 20),
              Text('證據政策：${prov.policy.code}',
                  style:
                      const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(prov.policy.detail,
                  style: const TextStyle(
                      fontSize: 12.8, color: Palette.inkSoft, height: 1.5)),
              if (prov.sources.isNotEmpty) ...[
                const Divider(height: 20),
                const Text('資料來源版本',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                ...prov.sources.entries.map((e) => _row(e.key, e.value)),
              ],
              const Divider(height: 20),
              const Text(
                '地圖上的熱點是機制模型的模擬情境，參數來自公開文獻，沒有用臺北市資料校準過。'
                '它不能推估任何一格實際有幾隻老鼠，也不能用來決定餌劑種類、劑量或投放地點。\n\n'
                '民眾通報是本 app 自己收到的資料，與見鼠雷達分開存放，不回灌進模型。',
                style: TextStyle(
                    fontSize: 12.5, color: Palette.inkSoft, height: 1.55),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了')),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 92,
            child: Text(k,
                style:
                    const TextStyle(fontSize: 12, color: Palette.inkFaint)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ]),
      );
}

/// 品牌標記。
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
      decoration: BoxDecoration(
        color: Palette.surface,
        border: Border.all(color: Palette.hair),
        borderRadius: BorderRadius.circular(13),
        boxShadow: Palette.cardShadow,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Palette.brand,
            borderRadius: BorderRadius.circular(9),
          ),
          // TODO: 換成 logo 圖檔，放進 assets/ 並在 pubspec 宣告。
          child: const Icon(Icons.hexagon_outlined,
              size: 17, color: Colors.white),
        ),
        const SizedBox(width: 8),
        const Text('Subterrat',
            style: TextStyle(
                fontSize: TypeScale.title,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.68,
                color: Palette.ink)),
      ]),
    );
  }
}

/// 圓角方形圖示按鈕，對齊 Figma 的 42×42 / radius 13。
class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.badge = 0,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final int badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: filled ? Palette.brand : Palette.surface,
          border: Border.all(color: filled ? Palette.brand : Palette.hair),
          borderRadius: BorderRadius.circular(13),
          boxShadow: Palette.cardShadow,
        ),
        child: Icon(icon,
            size: 21, color: filled ? Colors.white : Palette.ink),
      ),
    );

    final wrapped = badge > 0
        ? Stack(clipBehavior: Clip.none, children: [
            btn,
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Palette.danger,
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('$badge',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ])
        : btn;

    return tooltip == null
        ? wrapped
        : Tooltip(message: tooltip!, child: wrapped);
  }
}

/// 地圖縮放。Figma 有這一組，Google 內建的樣式對不上，所以自己畫。
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onIn, required this.onOut});

  final VoidCallback onIn;
  final VoidCallback onOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      decoration: BoxDecoration(
        color: Palette.surface,
        border: Border.all(color: Palette.hair),
        borderRadius: BorderRadius.circular(12),
        boxShadow: Palette.cardShadow,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _btn(Icons.add, onIn),
        const Divider(height: 1),
        _btn(Icons.remove, onOut),
      ]),
    );
  }

  Widget _btn(IconData i, VoidCallback f) => InkWell(
        onTap: f,
        child: SizedBox(
            width: 38, height: 36, child: Icon(i, size: 21, color: Palette.ink)),
      );
}

/// 圖上顏色的一句話說明。
class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.mode});

  final ObservedDisplay mode;

  @override
  Widget build(BuildContext context) {
    final text = switch (mode) {
      ObservedDisplay.points => '橘圈為預測不確定範圍・綠點命中・粉點未命中',
      ObservedDisplay.density => '橘圈為預測不確定範圍・紫色深淺為通報密度',
      ObservedDisplay.off => '橘圈為預測不確定範圍',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.ink.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: TypeScale.micro, color: Colors.white)),
    );
  }
}

/// 資料資訊面板。對齊 Figma 的 Data Info Panel。
class _DataInfoPanel extends StatelessWidget {
  const _DataInfoPanel({required this.prov, required this.onClose});

  final Provenance prov;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Palette.surface,
        border: Border.all(color: Palette.hair),
        borderRadius: BorderRadius.circular(14),
        boxShadow: Palette.panelShadow,
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Text('資料資訊',
                  style: TextStyle(
                      fontSize: TypeScale.label, fontWeight: FontWeight.w700)),
              const Spacer(),
              InkWell(
                onTap: onClose,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      size: 16, color: Palette.inkSoft),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _field('release_id', prov.releaseId),
            _field('freeze_id', prov.isFrozen ? prov.freezeId : 'NOT_FROZEN'),
            _field('score_semantics', prov.scoreSemantics),
            _field('evidence_state', prov.policy.code),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Palette.warnBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                  '目前是結構性風險排序，尚無可信驗證結果。分數用於排序，不是機率。',
                  style: TextStyle(
                      fontSize: TypeScale.caption,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: Palette.warnInk)),
            ),
          ]),
    );
  }

  Widget _field(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 96,
            child: Text(k,
                style: const TextStyle(
                    fontSize: TypeScale.micro, color: Palette.inkSoft)),
          ),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Palette.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(v,
                  style: const TextStyle(
                      fontFamily: kMonoFamily,
                      fontSize: TypeScale.micro,
                      height: 1.45,
                      color: Color(0xFF33423C))),
            ),
          ),
        ]),
      );
}

class _WeekBadge extends StatelessWidget {
  const _WeekBadge({required this.week, required this.date});

  final int week;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final today = week == RatSim.startWeek;
    return _Chip(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text('${date.month} 月 ${date.day} 日',
              style: const TextStyle(
                  fontSize: TypeScale.label,
                  fontWeight: FontWeight.w700,
                  color: Palette.ink)),
          const SizedBox(width: 6),
          if (today)
            const Text('今天',
                style: TextStyle(
                    fontSize: TypeScale.micro, color: Palette.inkSoft)),
        ]),
        Text(
            '第 $week 週　${week < RatSim.startWeek ? "投藥前" : "投藥後"}',
            style: const TextStyle(
                fontSize: TypeScale.micro, color: Palette.inkFaint)),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return _Chip(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('老鼠熱點強度',
            style: TextStyle(fontSize: 11, color: Palette.inkFaint)),
        const SizedBox(height: 5),
        Row(
          children: Palette.riskRamp
              .map((c) => Container(width: 18, height: 9, color: c))
              .toList(),
        ),
        const SizedBox(height: 3),
        const SizedBox(
          width: 126,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('低', style: TextStyle(fontSize: 10, color: Palette.inkFaint)),
              Text('高', style: TextStyle(fontSize: 10, color: Palette.inkFaint)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// 通報點位圖層開關，以及圈選命中率。
class _VerifyPanel extends StatelessWidget {
  const _VerifyPanel({
    required this.mode,
    required this.hits,
    required this.total,
    required this.capture,
    required this.topKPercent,
    required this.isMock,
    required this.onMode,
  });

  final ObservedDisplay mode;
  final int hits;
  final int total;
  final double capture;
  final int topKPercent;
  final bool isMock;
  final ValueChanged<ObservedDisplay> onMode;

  @override
  Widget build(BuildContext context) {
    return _Chip(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('觀測通報',
              style: TextStyle(
                  fontSize: TypeScale.caption, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: ObservedDisplay.values.map((m) {
              final on = m == mode;
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: InkWell(
                  onTap: () => onMode(m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: on ? Palette.brand : Palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(m.label,
                        style: TextStyle(
                            fontSize: TypeScale.micro,
                            fontWeight: FontWeight.w600,
                            color: on ? Colors.white : Palette.inkSoft)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 168,
            child: Text(mode.hint,
                style: const TextStyle(
                    fontSize: 10.5, color: Palette.inkFaint, height: 1.35)),
          ),
          if (total > 0 && mode == ObservedDisplay.points) ...[
            const Divider(height: 11),
            Text('前 $topKPercent% 圈選命中',
                style: const TextStyle(fontSize: 10.5, color: Palette.inkFaint)),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic, children: [
              Text('${(capture * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Palette.ink)),
              const SizedBox(width: 6),
              Text('$hits / $total 筆',
                  style: const TextStyle(
                      fontSize: 11, color: Palette.inkSoft)),
            ]),
            Row(children: [
              _dot(const Color(0xFF1B8A3A)),
              const Text(' 命中　',
                  style: TextStyle(fontSize: 10.5, color: Palette.inkFaint)),
              _dot(const Color(0xFFD4416B)),
              const Text(' 未命中',
                  style: TextStyle(fontSize: 10.5, color: Palette.inkFaint)),
            ]),
            if (isMock)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: 168,
                  child: Text('示範資料，這個數字沒有意義。接上見鼠雷達後才算數。',
                      style: TextStyle(
                          fontSize: 10, color: Palette.danger, height: 1.35)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Palette.surface,
          border: Border.all(color: Palette.hair),
        ),
        child: child,
      );
}

class _CellCard extends StatelessWidget {
  const _CellCard(
      {required this.cell, required this.heat, required this.onClose});

  final RiskCell cell;
  final double heat;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _Chip(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${cell.district}　${cell.cellId}',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          InkWell(
            onTap: onClose,
            child: const Icon(Icons.close, size: 16, color: Palette.inkFaint),
          ),
        ]),
        const Divider(height: 13),
        _kv('此刻熱點強度', heat.toStringAsFixed(2)),
        _kv('結構性篩選分數', cell.structuralScore.toStringAsFixed(2)),
        _kv('食物豐度', cell.carryingCapacity.round().toString()),
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: 2),
          child: Text('分數為排序用，非機率',
              style: TextStyle(fontSize: 10.5, color: Palette.danger)),
        ),
        if (cell.topFactors.isNotEmpty) ...[
          const SizedBox(height: 7),
          const Text('主要成因',
              style: TextStyle(fontSize: 11, color: Palette.inkFaint)),
          const SizedBox(height: 3),
          ...cell.topFactors.map((f) => Text('· $f',
              style: const TextStyle(fontSize: 12, color: Palette.inkSoft))),
        ],
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
            child: Text(k,
                style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
          ),
          const SizedBox(width: 8),
          Text(v,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Palette.ink)),
        ]),
      );
}

class _TimeBar extends StatelessWidget {
  const _TimeBar({
    required this.week,
    required this.baitWeeks,
    required this.playing,
    required this.onWeek,
    required this.onPlay,
  });

  final int week;
  final List<int> baitWeeks;
  final bool playing;
  final ValueChanged<int> onWeek;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.surface,
      padding: const EdgeInsets.fromLTRB(6, 2, 12, 2),
      child: Row(children: [
        IconButton(
          onPressed: onPlay,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          color: Palette.accent,
          tooltip: playing ? '暫停' : '播放時間軸',
        ),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 7,
              child: LayoutBuilder(
                builder: (ctx, box) => Stack(
                  children: baitWeeks
                      .map((b) => Positioned(
                            left: b / (RatSim.weeks - 1) * box.maxWidth,
                            child: Container(
                                width: 1.5, height: 7, color: Palette.hair),
                          ))
                      .toList(),
                ),
              ),
            ),
            Slider(
              value: week.toDouble(),
              min: 0,
              max: (RatSim.weeks - 1).toDouble(),
              divisions: RatSim.weeks - 1,
              label: '第 $week 週',
              onChanged: (v) => onWeek(v.round()),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ScenarioTab extends StatelessWidget {
  const _ScenarioTab({required this.params, required this.onChanged});

  final SimParams params;
  final ValueChanged<SimParams> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      children: [
        _slider(
          '每次投藥毒到多少老鼠',
          '${(params.baseUptake * 100).round()}%',
          '不是所有老鼠都會去吃餌。周圍食物越多，願意吃餌的越少，'
              '所以食物豐盛的地方這個數字會自動被壓低。',
          params.baseUptake,
          0.1,
          0.9,
          16,
          (v) => onChanged(params.copyWith(baseUptake: v)),
        ),
        _slider(
          '多久投一次藥',
          '每 ${params.periodWeeks} 週',
          '間隔越長，老鼠越有時間生回來。這個比「毒到多少」更能決定成敗。',
          params.periodWeeks.toDouble(),
          2,
          26,
          24,
          (v) => onChanged(params.copyWith(periodWeeks: v.round())),
        ),
        _slider(
          '周邊移入',
          '${(params.migration * 100).round()}%',
          '把這一格清乾淨之後，旁邊沒處理的地方會有老鼠搬過來填補。'
              '拉高看看：只處理一個點會變得幾乎沒有用。',
          params.migration,
          0,
          0.4,
          40,
          (v) => onChanged(params.copyWith(migration: v)),
        ),
      ],
    );
  }

  Widget _slider(String title, String value, String hint, double v, double min,
      double max, int divisions, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Palette.accent)),
        ]),
        Slider(
            value: v,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged),
        Text(hint,
            style: const TextStyle(
                fontSize: 11.5, color: Palette.inkFaint, height: 1.45)),
      ]),
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.rows, required this.onTap});

  final List<ScheduleRow> rows;
  final ValueChanged<RiskCell> onTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('沒有資料'));
    return Column(children: [
      Container(
        color: Palette.surfaceAlt,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: const Row(children: [
          Expanded(flex: 4, child: _H('位置')),
          Expanded(flex: 3, child: _H('壓不下去的程度')),
          Expanded(flex: 3, child: _H('多久長回來')),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final r = rows[i];
            return InkWell(
              onTap: () => onTap(r.cell),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.cell.district,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(r.cell.cellId,
                              style: const TextStyle(
                                  fontSize: 11, color: Palette.inkFaint)),
                        ]),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(children: [
                      Container(
                          width: 9,
                          height: 9,
                          color: Palette.riskColor(r.steadyRatio)),
                      const SizedBox(width: 6),
                      Text('${(r.steadyRatio * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                        r.reboundWeeks == null ? '沒長回來' : '${r.reboundWeeks} 週',
                        style: const TextStyle(
                            fontSize: 13, color: Palette.inkSoft)),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.reports, required this.onAdd});

  final List<CitizenReport> reports;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.pin_drop_outlined,
                size: 32, color: Palette.inkFaint),
            const SizedBox(height: 8),
            const Text('還沒有通報',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            const Text('把地圖移到看到老鼠的位置，再按右下角的通報鈕。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Palette.inkFaint)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_alert_outlined, size: 17),
              label: const Text('我要通報'),
            ),
          ]),
        ),
      );
    }
    return ListView.separated(
      itemCount: reports.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final r = reports[i];
        return ListTile(
          dense: true,
          leading: Icon(
            r.pending ? Icons.schedule : Icons.check_circle_outline,
            size: 19,
            color: r.pending ? Palette.danger : Palette.accent,
          ),
          title: Text(r.kind.label,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              _HomePageState._fmtTime(r.reportedAt),
              '${r.location.latitude.toStringAsFixed(4)}, '
                  '${r.location.longitude.toStringAsFixed(4)}',
              if (r.note.isNotEmpty) r.note,
            ].join('　'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Palette.inkFaint),
          ),
          trailing: r.pending
              ? const Text('待送出',
                  style: TextStyle(fontSize: 11, color: Palette.danger))
              : null,
        );
      },
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: Palette.inkFaint));
}
