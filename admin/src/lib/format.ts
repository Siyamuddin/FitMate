export function formatDay(date = new Date()) {
  return new Intl.DateTimeFormat('en-GB', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
  }).format(date)
}

export function formatWhen(value: string | null | undefined) {
  if (!value) return 'Never'
  return new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value))
}

export function formatNumber(value: number) {
  return new Intl.NumberFormat('en-GB').format(value)
}

export function formatCost(value: number | string | null | undefined) {
  const amount = Number(value ?? 0)
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 4,
  }).format(amount)
}

export function countsByDay(timestamps: string[], days: number) {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const buckets = Array.from({ length: days }, (_, index) => {
    const day = new Date(today)
    day.setDate(today.getDate() - (days - 1 - index))
    return { day, count: 0 }
  })
  for (const stamp of timestamps) {
    const point = new Date(stamp)
    point.setHours(0, 0, 0, 0)
    const match = buckets.find((bucket) => bucket.day.getTime() === point.getTime())
    if (match) match.count += 1
  }
  return buckets
}
