import { corsHeaders, json } from './cors.ts'
import { requireUser } from './auth.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const { supabase } = await requireUser(req)
    const body = await req.json()
    const actions = Array.isArray(body.actions) ? body.actions : []
    if (!actions.length) throw new Error('no_actions')
    const dismissed = body.dismissed === true
    const applied: string[] = []

    for (const action of actions) {
      const type = String(action?.type ?? '')
      if (!type) continue
      await supabase.from('ai_actions').update({
        status: dismissed ? 'rejected' : 'executed',
        result: { ok: true, source: 'client' },
      }).eq('action_type', type).eq('status', 'proposed')
      applied.push(type)
    }

    const { data: messages } = await supabase
      .from('ai_messages')
      .select('id, content')
      .eq('role', 'assistant')
      .order('created_at', { ascending: false })
      .limit(20)

    for (const row of messages ?? []) {
      const content = row.content && typeof row.content === 'object' ? row.content as Record<string, unknown> : null
      if (!content) continue
      const existing = Array.isArray(content.actions) ? content.actions : []
      if (!existing.length) continue
      await supabase.from('ai_messages').update({
        content: {
          ...content,
          applied: dismissed ? content.applied === true : true,
          dismissed,
        },
      }).eq('id', row.id)
      break
    }

    if (!applied.length) throw new Error('nothing_applied')
    return json({ ok: true, applied })
  } catch (error) {
    console.error('apply_ai_action_failed', error)
    if (error instanceof Response) return error
    return json({ error: 'Could not confirm those changes.' }, 400)
  }
})
