'use server'

import { requireAdmin } from '@/lib/require-admin'
import { revalidatePath } from 'next/cache'

export async function setCoachEnabled(id: string, enabled: boolean) {
  const { supabase } = await requireAdmin()
  const { error } = await supabase.from('ai_configurations').update({ enabled, updated_at: new Date().toISOString() }).eq('id', id)
  if (error) return { error: error.message }
  revalidatePath('/model')
  revalidatePath('/overview')
  return { error: null }
}

export async function saveModel(input: {
  id: string
  model: string
  max_output_tokens: number
  daily_request_limit: number
  enabled_tools: string[]
}) {
  const { supabase } = await requireAdmin()
  if (!Number.isFinite(input.max_output_tokens) || input.max_output_tokens < 200) {
    return { error: 'Max output tokens must be at least 200.' }
  }
  if (!Number.isFinite(input.daily_request_limit) || input.daily_request_limit < 1) {
    return { error: 'Daily request limit must be at least 1.' }
  }
  const { error } = await supabase
    .from('ai_configurations')
    .update({
      model: input.model,
      max_output_tokens: input.max_output_tokens,
      daily_request_limit: input.daily_request_limit,
      enabled_tools: input.enabled_tools,
      updated_at: new Date().toISOString(),
    })
    .eq('id', input.id)
  if (error) return { error: error.message }
  revalidatePath('/model')
  revalidatePath('/overview')
  return { error: null }
}
