import { adminClient } from './auth.ts'

export const DEFAULT_MODEL = 'gpt-5.6-luna'

async function openaiKey() {
  const { data, error } = await adminClient().rpc('read_app_secret', { p_name: 'OPENAI_API_KEY' })
  if (!error && typeof data === 'string' && data) return data
  const fromEnv = Deno.env.get('OPENAI_API_KEY')
  if (fromEnv) return fromEnv
  throw new Error('OPENAI_API_KEY is not configured')
}

function isGpt56Family(model: string) {
  return model.includes('gpt-5.6') || model.includes('luna') || model.includes('terra') || model.includes('sol')
}

function messageText(content: unknown): string {
  if (typeof content === 'string') return content
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === 'string') return part
        if (part && typeof part === 'object' && 'text' in part) {
          return String((part as { text?: unknown }).text ?? '')
        }
        return ''
      })
      .join('')
  }
  return ''
}

export async function chatJson(args: {
  model: string
  temperature: number
  maxTokens: number
  system: string
  user?: string
  messages?: { role: string; content: string }[]
  tools?: unknown[]
}) {
  const key = await openaiKey()
  const history = (args.messages ?? []).filter(
    (item) => item.role === 'user' || item.role === 'assistant' || item.role === 'system',
  )
  const messages: { role: string; content: string }[] = [
    { role: 'system', content: args.system },
    ...history,
  ]
  if (args.user) {
    messages.push({ role: 'user', content: args.user })
  }
  const body: Record<string, unknown> = {
    model: args.model,
    max_completion_tokens: args.maxTokens,
    response_format: { type: 'json_object' },
    messages,
  }
  if (isGpt56Family(args.model)) {
    body.reasoning_effort = 'low'
  } else {
    body.temperature = args.temperature
    body.max_tokens = args.maxTokens
  }
  if (args.tools) {
    body.tools = args.tools
  }
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })
  if (!response.ok) {
    const detail = await response.text()
    console.error('openai_error', response.status, detail)
    throw new Error('The coach is temporarily unavailable.')
  }
  const json = await response.json()
  const content = messageText(json.choices?.[0]?.message?.content) || '{}'
  const usage = json.usage ?? { prompt_tokens: 0, completion_tokens: 0 }
  return {
    parsed: JSON.parse(content),
    usage,
    model: json.model as string,
  }
}
