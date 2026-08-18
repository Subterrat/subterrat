import type { ScoreKey } from "./types";

export type LayerDefinition = {
  key: ScoreKey;
  shortLabel: string;
  label: string;
  group:
    | "v0.1 reference"
    | "v0.2 sewer"
    | "v0.3 admin proxy"
    | "v0.3 internal simulation";
  caveat: string;
};

export const LAYERS: LayerDefinition[] = [
  {
    key: "food_market_v0_1",
    shortLabel: "餐飲 v0.1",
    label: "餐飲／市場 percentile（v0.1）",
    group: "v0.1 reference",
    caveat: "Frozen v0.1 reference；不是鼠患機率。",
  },
  {
    key: "sewer_system_type_v0_1",
    shortLabel: "下水道 v0.1",
    label: "污水系統類型 percentile（v0.1）",
    group: "v0.1 reference",
    caveat: "僅 system-type，且只有部分臺北面積可計分。",
  },
  {
    key: "sewer_system_type_v0_2",
    shortLabel: "系統類型",
    label: "Sewer system type diagnostic（v0.2）",
    group: "v0.2 sewer",
    caveat: "沿用 v0.1 PASS component。",
  },
  {
    key: "surface_elevation_v0_2",
    shortLabel: "地表高程",
    label: "Surface elevation diagnostic（v0.2）",
    group: "v0.2 sewer",
    caveat: "欄位語義與 coverage 仍為 conditional。",
  },
  {
    key: "connected_pipe_diameter_v0_2",
    shortLabel: "管徑",
    label: "Connected pipe diameter diagnostic（v0.2）",
    group: "v0.2 sewer",
    caveat: "方向為較窄較高分；幾何與 coverage gate 未完成。",
  },
  {
    key: "connected_pipe_depth_v0_2",
    shortLabel: "埋深",
    label: "Connected pipe depth diagnostic（v0.2）",
    group: "v0.2 sewer",
    caveat: "方向為較淺較高分；outlier rule 尚未取得權威依據。",
  },
  {
    key: "connected_pipe_age_v0_2",
    shortLabel: "管齡",
    label: "Connected pipe age diagnostic（v0.2）",
    group: "v0.2 sewer",
    caveat: "方向為較老較高分；安裝日期集中仍待查證。",
  },
  {
    key: "sewer_attribute_index_v0_2",
    shortLabel: "下水道加強版",
    label: "Sewer attribute index：五項 complete-case mean（v0.2）",
    group: "v0.2 sewer",
    caveat: "Simulation-only；包含 blocked/conditional diagnostics。",
  },
  {
    key: "approved_rebuilding_admin_site_buffer_0m",
    shortLabel: "都更 0 m",
    label: "核定重建行政 site proxy：cell footprint 0 m（sensitivity）",
    group: "v0.3 admin proxy",
    caveat: "行政資料不代表施工、物理擾動或真實不存在；來源 reuse gate 未完成。",
  },
  {
    key: "approved_rebuilding_admin_site_buffer_150m",
    shortLabel: "都更 150 m",
    label: "核定重建行政 site proxy：cell-footprint buffer 150 m",
    group: "v0.3 admin proxy",
    caveat: "預註冊分析 window；不是擴散、位移、活動範圍或施工距離。",
  },
  {
    key: "approved_rebuilding_admin_site_buffer_300m",
    shortLabel: "都更 300 m",
    label: "核定重建行政 site proxy：cell-footprint buffer 300 m（sensitivity）",
    group: "v0.3 admin proxy",
    caveat: "Sensitivity only；不得依見鼠結果選半徑。",
  },
  {
    key: "v0_3_equal_group_internal_simulation_r150",
    shortLabel: "v0.3 綜合",
    label: "餐飲＋sewer attribute＋都更行政 proxy 等權 internal simulation",
    group: "v0.3 internal simulation",
    caveat: "三組各 1/3；僅內部 ordinal simulation，NO_TRUSTED_RESULT。",
  },
];

export const DEFAULT_LAYER: ScoreKey =
  "v0_3_equal_group_internal_simulation_r150";
