import { corsHeaders, json } from '../_shared/cors.ts'
import { adminClient, requireUser } from '../_shared/auth.ts'
import { buildContext } from '../_shared/context.ts'
import { chatJson } from '../_shared/openai.ts'
import { failClosedMessage, sanitizeUserMessage } from '../_shared/safety.ts'
import {
  APPLIABLE_ACTIONS,
  asStringList,
  honestCoachMessage,
  messageTextFromContent,
} from '../_shared/honesty.ts'
import { FALLBACK_COACH_INSTRUCTION, FALLBACK_SYSTEM_PROMPT } from '../_shared/coach_prompt.ts'
import { enforceRateLimit, recordUsage } from '../_shared/usage.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const { user, supabase } = await requireUser(req)
    const admin = adminClient()
    const config = await enforceRateLimit(admin, user.id)
    const body = await req.json()
    const message = sanitizeUserMessage(String(body.message ?? ''))
    if (!message) return json({ error: 'Message required' }, 400)

    const context = await buildContext(supabase, user.id)
    const { data: prompt } = await admin.from('ai_prompt_versions').select('*').eq('is_active', true).maybeSingle()

    const startFresh = body.new_conversation === true
    let conversationId = startFresh ? undefined : body.conversation_id as string | undefined
    if (!conversationId) {
      if (!startFresh) {
        const { data: existing } = await supabase.from('ai_conversations').select('id').order('updated_at', { ascending: false }).limit(1).maybeSingle()
        if (existing) conversationId = existing.id
      }
      if (!conversationId) {
        const { data: created } = await supabase.from('ai_conversations').insert({ user_id: user.id, title: 'Coach' }).select('id').single()
        conversationId = created?.id
      }
    }

    const history: { role: string; content: string }[] = []
    if (conversationId) {
      const { data: prior } = await supabase
        .from('ai_messages')
        .select('role, content, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: false })
        .limit(8)
      history.push(
        ...(prior ?? [])
          .slice()
          .reverse()
          .map((row: { role: string; content: unknown }) => ({
            role: row.role === 'assistant' ? 'assistant' : 'user',
            content: messageTextFromContent(row.content),
          }))
          .filter((row: { content: string }) => row.content.length > 0),
      )
    }

    await supabase.from('ai_messages').insert({
      conversation_id: conversationId,
      role: 'user',
      content: { message },
    })

    const result = await chatJson({
      model: config?.model ?? prompt?.model ?? 'gpt-5.6-luna',
      temperature: Number(config?.temperature ?? 0.4),
      maxTokens: config?.max_output_tokens ?? 1200,
      system: `${prompt?.system_prompt ?? FALLBACK_SYSTEM_PROMPT}\n${prompt?.coach_instruction ?? FALLBACK_COACH_INSTRUCTION}`,
      messages: history,
      user: JSON.stringify({ message, context }),
    })

    const intent = String(result.parsed.intent ?? '').toLowerCase()
    const rawActions = Array.isArray(result.parsed.actions) ? result.parsed.actions as Record<string, unknown>[] : []
    const actions = intent === 'propose'
      ? rawActions.filter((action) => APPLIABLE_ACTIONS.has(String(action.type ?? '')))
      : []
    const droppedUnsupported = intent === 'propose' && rawActions.length > actions.length
    const requiresConfirmation = actions.length > 0
    const previewLines = asStringList(result.parsed.preview_lines)
    const clarifyingQuestions = intent === 'clarify' ? asStringList(result.parsed.clarifying_questions).slice(0, 2) : []
    const bullets = asStringList(result.parsed.bullets)

    const messageText = honestCoachMessage({
      message: String(result.parsed.message ?? ''),
      intent,
      requiresConfirmation,
      applied: false,
      droppedUnsupported,
    })

    const { data: assistant } = await supabase.from('ai_messages').insert({
      conversation_id: conversationId,
      role: 'assistant',
      content: {
        ...result.parsed,
        message: messageText,
        intent: requiresConfirmation ? 'propose' : (intent || 'answer'),
        requires_confirmation: requiresConfirmation,
        actions,
        preview_lines: previewLines,
        clarifying_questions: clarifyingQuestions,
        bullets,
        applied: false,
      },
      prompt_version_id: prompt?.id ?? null,
    }).select('id').single()

    if (actions.length) {
      await supabase.from('ai_actions').insert(actions.map((action) => ({
        conversation_id: conversationId,
        message_id: assistant?.id,
        action_type: action.type,
        arguments: action,
        status: 'proposed',
        requires_confirmation: true,
        result: null,
      })))
    }

    await recordUsage(admin, {
      userId: user.id,
      conversationId,
      model: result.model,
      input: result.usage.prompt_tokens,
      output: result.usage.completion_tokens,
      promptVersionId: prompt?.id,
    })

    return json({
      message: messageText,
      intent: requiresConfirmation ? 'propose' : (intent || 'answer'),
      requires_confirmation: requiresConfirmation,
      applied: false,
      actions: requiresConfirmation ? actions : [],
      preview_lines: previewLines,
      clarifying_questions: clarifyingQuestions,
      bullets,
      conversation_id: conversationId,
    })
  } catch (error) {
    if (error instanceof Response) return error
    const message = error instanceof Error ? error.message : 'chat_failed'
    if (message === 'rate_limited') return json({ error: 'Daily coaching limit reached.' }, 429)
    if (message === 'coach_disabled') return json({ error: 'Coaching is temporarily unavailable.' }, 400)
    return json({ error: failClosedMessage() }, 400)
  }
})
