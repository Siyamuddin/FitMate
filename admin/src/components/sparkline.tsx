export function Sparkline({ values, label }: { values: number[]; label: string }) {
  const width = 320
  const height = 72
  const max = Math.max(...values, 1)
  const points = values
    .map((value, index) => {
      const x = values.length === 1 ? 0 : (index / (values.length - 1)) * width
      const y = height - (value / max) * (height - 8) - 4
      return `${x},${y}`
    })
    .join(' ')

  return (
    <svg width="100%" viewBox={`0 0 ${width} ${height}`} role="img" aria-label={label} className="text-accent">
      <polyline fill="none" stroke="currentColor" strokeWidth="2" points={points} />
    </svg>
  )
}
