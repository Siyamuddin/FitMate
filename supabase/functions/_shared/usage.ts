import { SupabaseClient } from 'npm:@supabase/supabase-js@2'

export async function enforceRateLimit(admin: SupabaseClient, userId: string) {
  const { data: config } = await admin.from('ai_configurations').select('*').limit(1).maybeSingle()
  const limit = config?.daily_request_limit ?? 50
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const { count } = await admin
    .from('ai_usage')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', since)
  if (config && config.enabled === false) {
    throw new Error('coach_disabled')
  }
  if ((count ?? 0) >= limit) {
    throw new Error('rate_limited')
  }
  return config
}

export async function recordUsage(
  admin: SupabaseClient,
  args: { userId: string; conversationId?: string; model: string; input: number; output: number; promptVersionId?: string },
) {
  const estimated = (args.input * 0.000005) + (args.output * 0.000015)
  await admin.from('ai_usage').insert({
    user_id: args.userId,
    conversation_id: args.conversationId ?? null,
    model: args.model,
    input_tokens: args.input,
    output_tokens: args.output,
    estimated_cost: estimated,
    prompt_version_id: args.promptVersionId ?? null,
  })
}
