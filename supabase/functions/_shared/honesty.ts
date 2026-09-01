export const APPLIABLE_ACTIONS = new Set([
  'modify_workout_exercise',
  'modify_workout_day',
  'update_training_plan',
  'create_workout_plan',
  'update_goal',
  'record_weight',
])

const CLAIMED_DONE = /\b(i('ve| have)? (just )?(updated|changed|applied|saved|added|modified|set)|your plan (is now|has been)|all set|it's done|change is (done|complete))\b/i

export function asProposal(text: string) {
  return text
    .replace(/\bI've (just )?(updated|changed|applied|saved|added|modified)\b/gi, 'I can $2')
    .replace(/\bI have (just )?(updated|changed|applied|saved|added|modified)\b/gi, 'I can $2')
    .replace(/\bI (updated|changed|applied|saved|added|modified)\b/gi, 'I can $2')
    .replace(/\byour plan is now\b/gi, 'your plan would be')
    .replace(/\byour plan has been\b/gi, 'your plan would be')
}

export function honestCoachMessage(args: {
  message: string
  requiresConfirmation: boolean
  applied: boolean
  droppedUnsupported: boolean
}) {
  const raw = (args.message || '').trim() || 'I am here to help with your training.'
  if (args.droppedUnsupported && !args.requiresConfirmation && !args.applied) {
    return "I didn't change your plan. I can walk you through it, but I can't save that kind of change yet."
  }
  if (args.requiresConfirmation) {
    const proposal = CLAIMED_DONE.test(raw) ? asProposal(raw) : raw
    if (/tap apply|not saved yet|proposal/i.test(proposal)) return proposal
    return `${proposal}\n\nThis is not saved yet. Tap Apply to update your plan.`
  }
  if (!args.applied && CLAIMED_DONE.test(raw)) {
    return "I didn't change your plan."
  }
  return raw
}
