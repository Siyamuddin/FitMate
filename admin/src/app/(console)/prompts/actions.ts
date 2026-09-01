'use server'

import { requireAdmin } from '@/lib/require-admin'
import { revalidatePath } from 'next/cache'

export async function createPromptVersion(input: {
  system_prompt: string
  coach_instruction: string
  plan_instruction: string
  model: string
  publish: boolean
}) {
  const { supabase, user } = await requireAdmin()
  const system = input.system_prompt.trim()
  if (!system) return { error: 'System prompt cannot be empty.' }

  const { data: latest } = await supabase
    .from('ai_prompt_versions')
    .select('version')
    .order('version', { ascending: false })
    .limit(1)
    .maybeSingle()
  const nextVersion = (latest?.version ?? 0) + 1

  if (input.publish) {
    await supabase.from('ai_prompt_versions').update({ is_active: false }).eq('is_active', true)
  }

  const { error } = await supabase.from('ai_prompt_versions').insert({
    version: nextVersion,
    system_prompt: system,
    coach_instruction: input.coach_instruction.trim(),
    plan_instruction: input.plan_instruction.trim(),
    model: input.model,
    temperature: 0.4,
    is_active: input.publish,
    created_by: user.id,
  })
  if (error) return { error: error.message }
  revalidatePath('/prompts')
  revalidatePath('/overview')
  return { error: null, version: nextVersion }
}

export async function publishPrompt(id: string) {
  const { supabase } = await requireAdmin()
  await supabase.from('ai_prompt_versions').update({ is_active: false }).eq('is_active', true)
  const { error } = await supabase.from('ai_prompt_versions').update({ is_active: true }).eq('id', id)
  if (error) return { error: error.message }
  revalidatePath('/prompts')
  revalidatePath('/overview')
  return { error: null }
}
