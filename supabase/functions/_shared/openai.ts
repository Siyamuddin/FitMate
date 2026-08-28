export async function chatJson(args: {
  model: string
  temperature: number
  maxTokens: number
  system: string
  user: string
  tools?: unknown[]
}) {
  const key = Deno.env.get('OPENAI_API_KEY')
  if (!key) {
    throw new Error('OPENAI_API_KEY is not configured')
  }
  const body: Record<string, unknown> = {
    model: args.model,
    temperature: args.temperature,
    max_tokens: args.maxTokens,
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: args.system },
      { role: 'user', content: args.user },
    ],
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
    throw new Error('The coach is temporarily unavailable.')
  }
  const json = await response.json()
  const content = json.choices?.[0]?.message?.content ?? '{}'
  const usage = json.usage ?? { prompt_tokens: 0, completion_tokens: 0 }
  return {
    parsed: JSON.parse(content),
    usage,
    model: json.model as string,
  }
}
