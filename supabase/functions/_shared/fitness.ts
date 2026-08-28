export type FitnessInput = {
  age: number
  sex: 'male' | 'female' | 'other'
  heightCm: number
  weightKg: number
  activityLevel: 'sedentary' | 'lightly_active' | 'moderately_active' | 'very_active' | 'extra_active'
  goalType: 'lose_fat' | 'build_muscle' | 'get_stronger' | 'improve_fitness' | 'maintain_weight' | 'custom'
}

export function bmr(input: FitnessInput): number {
  const base = 10 * input.weightKg + 6.25 * input.heightCm - 5 * input.age
  if (input.sex === 'male') return base + 5
  if (input.sex === 'female') return base - 161
  return base - 78
}

const multipliers: Record<FitnessInput['activityLevel'], number> = {
  sedentary: 1.2,
  lightly_active: 1.375,
  moderately_active: 1.55,
  very_active: 1.725,
  extra_active: 1.9,
}

export function targets(input: FitnessInput) {
  const bmrValue = bmr(input)
  const tdee = bmrValue * multipliers[input.activityLevel]
  let calories = tdee
  if (input.goalType === 'lose_fat') calories = tdee - 500
  if (input.goalType === 'build_muscle') calories = tdee + 250
  if (input.goalType === 'get_stronger') calories = tdee + 150
  const floor = input.sex === 'male' ? 1500 : 1200
  if (calories < floor) calories = floor
  const proteinPerKg = input.goalType === 'lose_fat' ? 2 : input.goalType === 'build_muscle' || input.goalType === 'get_stronger' ? 1.8 : 1.6
  const proteinG = Number((input.weightKg * proteinPerKg).toFixed(1))
  const fatG = Number(((calories * 0.25) / 9).toFixed(1))
  const carbohydratesG = Number((((calories - proteinG * 4 - fatG * 9) / 4)).toFixed(1))
  return { bmr: bmrValue, tdee, calories: Math.round(calories), proteinG, carbohydratesG, fatG }
}
