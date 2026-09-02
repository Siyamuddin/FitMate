export const APPLIABLE_ACTIONS = new Set([
  'modify_workout_exercise',
  'modify_workout_day',
  'update_training_plan',
  'create_workout_plan',
  'add_exercise',
  'remove_exercise',
  'replace_exercise',
  'add_food_log',
  'update_nutrition_targets',
  'update_goal',
  'record_weight',
  'update_profile',
])

const CLAIMED_DONE =
  /\b(i('ve| have)? (just )?(updated|changed|applied|saved|added|modified|set|logged)|your plan (is now|has been)|all set|it's done|change is (done|complete))\b/i

export function asProposal(text: string) {
  return text
    .replace(/\bI've (just )?(updated|changed|applied|saved|added|modified|logged)\b/gi, 'I can $2')
    .replace(/\bI have (just )?(updated|changed|applied|saved|added|modified|logged)\b/gi, 'I can $2')
    .replace(/\bI (updated|changed|applied|saved|added|modified|logged)\b/gi, 'I can $2')
    .replace(/\byour plan is now\b/gi, 'your plan would be')
    .replace(/\byour plan has been\b/gi, 'your plan would be')
}

export function honestCoachMessage(args: {
  message: string
  intent?: string
  requiresConfirmation: boolean
  applied: boolean
  droppedUnsupported: boolean
}) {
  const raw = (args.message || '').trim() || 'I am here to help with your training.'
  if (args.droppedUnsupported && !args.requiresConfirmation && !args.applied) {
    return "I didn't change your plan. I can walk you through it, but I can't save that kind of change yet."
  }
  if (args.intent === 'propose' || args.requiresConfirmation) {
    return CLAIMED_DONE.test(raw) ? asProposal(raw) : raw
  }
  if (!args.applied && CLAIMED_DONE.test(raw)) {
    return asProposal(raw)
  }
  return raw
}

export function asStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return []
  return value
    .map((item) => String(item ?? '').trim())
    .filter((item) => item.length > 0)
    .slice(0, 8)
}

export function messageTextFromContent(content: unknown): string {
  if (typeof content === 'string') return content
  if (!content || typeof content !== 'object') return ''
  const row = content as Record<string, unknown>
  const text = row.message ?? row.text
  return typeof text === 'string' ? text : ''
}
