export function validateSets(value: unknown) {
  const n = Number(value)
  if (!Number.isInteger(n) || n < 1 || n > 8) throw new Error('sets_out_of_range')
  return n
}

export function validateReps(value: unknown) {
  const n = Number(value)
  if (!Number.isInteger(n) || n < 1 || n > 50) throw new Error('reps_out_of_range')
  return n
}
