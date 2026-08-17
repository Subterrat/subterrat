import 'package:flutter/material.dart';

/// 介面配色。
///
/// 中性色沿用 Figma（`SubTerrat — Risk Map UI`）的定義，
/// 主色改為 logo 的深藍。熱點維持暖色系，與深藍形成對比。
class Palette {
  // ---- 主色 -------------------------------------------------------------
  // TODO: 換成 logo 的實際色碼。目前是佔位值。
  // 只要改這一個常數，整個 app 的主色都會跟著變。
  static const brand = Color(0xFF123A5E);
  static const brandDark = Color(0xFF0C2A45);
  static const brandSoft = Color(0xFFE7EDF3);

  /// 舊名保留，避免各處引用同時改。指向同一個主色。
  static const accent = brand;

  // ---- 中性色（取自 Figma） ---------------------------------------------
  static const ground = Color(0xFFE5EDE8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F5F3);
  static const ink = Color(0xFF17251F);
  static const inkSoft = Color(0xFF66746F);
  static const inkFaint = Color(0xFF78857F);
  static const hair = Color(0xFFDCE5E0);

  // ---- 語意色 -----------------------------------------------------------
  static const danger = Color(0xFFD63835);
  static const warnBg = Color(0xFFFFF1DC);
  static const warnInk = Color(0xFF744719);

  /// 圓形範圍標籤的文字色。Figma 用的是 #74420F，
  /// 跟 warnInk (#744719) 差一點，不要混用。
  static const uncertaintyInk = Color(0xFF74420F);
  static const hit = Color(0xFF1B8A3A);
  static const miss = Color(0xFFD4416B);

  // ---- 狀態列與資料來源面板（Figma: Data Status Strip / Structural Sources）
  static const statusBg = Color(0xFAFFF7EF);
  static const statusBorder = Color(0xFFEADCCF);
  static const evidenceBadge = Color(0xFFBF3A2F);
  static const metaLabel = Color(0xFF6F746F);
  static const metaValue = Color(0xFF4E5953);
  static const metaSep = Color(0xFF9B958D);
  static const semanticsPill = Color(0xFFEEE8E1);
  static const semanticsInk = Color(0xFF555F59);
  static const helperInk = Color(0xFF747B76);
  static const sourcePill = Color(0xFFE4EDE8);
  static const sourceInk = Color(0xFF2C5545);

  // ---- 通報抽屜（Figma: Government Demo Notice Drawer）
  //
  // Figma 這一組原本是綠色系（#126D50 / #12553F / #D2E9DE / #EEF7F2），
  // 但主色已改成深藍，留著綠色會變成第二個強調色。這裡改用深藍衍生色。
  static const noticeCard = Color(0xFFEDF2F7);
  static const noticeType = brand;
  static const inspectionPill = Color(0xFFD6E1EC);
  static const inspectionInk = Color(0xFF0E3252);
  static const demoDisclaimerBg = Color(0xFFFFF3DE);
  static const demoDisclaimerInk = Color(0xFF745329);
  static const closeBg = Color(0xFFF3F6F4);
  static const headline = Color(0xFF1B2822);
  static const bodyInk = Color(0xFF5E6C64);

  /// 觀測通報密度圖層的顏色。
  ///
  /// 用紫色是刻意的：預測範圍是橘色（色相約 25°），這個是約 265°，
  /// 兩者差 240°，疊在一起時分得開。原設計用紅色會跟橘色糊在一起，
  /// 而重疊區正好是最需要看清楚的地方。
  static const observedDensity = Color(0xFF4A3AA7);

  /// 卡片陰影，對齊 Figma 的 `0px 7px 22px rgba(21,49,40,0.13)`。
  static const cardShadow = [
    BoxShadow(
        color: Color(0x21153128), blurRadius: 22, offset: Offset(0, 7)),
  ];

  /// 面板陰影，對齊 Figma 的 `0px 12px 36px rgba(21,51,41,0.18)`。
  static const panelShadow = [
    BoxShadow(
        color: Color(0x2E153329), blurRadius: 36, offset: Offset(0, 12)),
  ];

  // ---- 熱點色階 ---------------------------------------------------------
  /// 暖色、單一色相、由淺到深。用暖色是因為它讀起來就是「熱」，
  /// 而且跟深藍主色互補，不會混淆。
  /// 最淺一階刻意接近底圖，讓低風險區融進地圖而不是連成一塊色塊。
  static const riskRamp = <Color>[
    Color(0xFFFFDDB0),
    Color(0xFFFBBC80),
    Color(0xFFF49355),
    Color(0xFFE86E38),
    Color(0xFFCE4A22),
    Color(0xFFA63417),
    Color(0xFF78240F),
  ];

  /// 圓形不確定範圍的主色，對齊 Figma 的 `#D96818` / `#DB6415`。
  static const uncertainty = Color(0xFFD96818);
  static const uncertaintyEdge = Color(0xD1D76A14);

  /// 低於這個值的格子完全不畫。沒有這道門檻，整張圖會是一塊實心方形。
  static const double heatFloor = 0.12;

  static Color riskColor(double v) {
    final x = v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
    return riskRamp[(x * (riskRamp.length - 1)).round()];
  }

  /// 熱點填色。透明度也跟著數值走 —— 只靠顏色的話每格同樣濃，
  /// 看起來會是方格拼貼而不是熱點圖。
  static Color heatFill(double v) {
    final x = v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
    if (x < heatFloor) return const Color(0x00000000);
    final t = (x - heatFloor) / (1 - heatFloor);
    return riskColor(x).withValues(alpha: 0.10 + 0.68 * (t * t * 0.5 + t * 0.5));
  }
}

/// 等寬字，用在代號與數值欄位（release_id、freeze_id、命中率等）。
///
/// 只打包 Latin 字符，約 100KB。中文沿用系統字型，
/// 不打包 CJK 字型以免 web 首次載入變慢。
const String kMonoFamily = 'DM Mono';

/// 字級。Figma 原稿最小到 7px，投影會看不見，這裡整體上調並收斂成六階。
class TypeScale {
  static const micro = 11.0; // 圖例、單位
  static const caption = 12.0; // 說明文字
  static const body = 13.0; // 內文
  static const label = 14.0; // 欄位標題
  static const title = 17.0; // 面板標題
  static const display = 22.0; // 數字強調
}

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.ground,
    colorScheme: base.colorScheme.copyWith(
      primary: Palette.brand,
      surface: Palette.surface,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: Palette.brand,
      thumbColor: Palette.brand,
      inactiveTrackColor: Palette.hair,
      trackHeight: 3,
    ),
    dividerTheme:
        const DividerThemeData(color: Palette.hair, thickness: 1, space: 1),
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
  );
}

/// 去飽和的底圖樣式。
///
/// 沒有這一段，Google 地圖本身的顏色會跟熱點色打架，
/// 尤其水域的藍會跟深藍主色混在一起。
const String kMutedMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"saturation":-85},{"lightness":12}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"saturation":-100},{"lightness":-20}]},
  {"elementType":"labels.text.stroke","stylers":[{"saturation":-100},{"lightness":60}]},
  {"featureType":"poi","stylers":[{"visibility":"simplified"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"saturation":-100},{"lightness":30}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"saturation":-90},{"lightness":25}]}
]
''';
