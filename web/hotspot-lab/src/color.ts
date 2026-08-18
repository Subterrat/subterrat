export function scoreColor(score: number): string {
  const bounded = Math.min(1, Math.max(0, score));
  const lightness = 94 - bounded * 56;
  const saturation = 58 + bounded * 18;
  return `hsl(211 ${saturation.toFixed(0)}% ${lightness.toFixed(0)}%)`;
}

export function formatScore(score: number | null): string {
  return score === null ? "無資料" : score.toFixed(3);
}
