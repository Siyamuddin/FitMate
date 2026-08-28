const INJECTION = /(ignore previous|system prompt|you are now|execute sql|service_role)/i

export function sanitizeUserMessage(input: string) {
  const trimmed = input.trim().slice(0, 2000)
  if (INJECTION.test(trimmed)) {
    return trimmed.replace(INJECTION, '[filtered]')
  }
  return trimmed
}

export function assertNoUserIdOverride(args: Record<string, unknown>) {
  if ('user_id' in args || 'userId' in args) {
    throw new Error('invalid_tool_args')
  }
}

export function failClosedMessage() {
  return "I couldn't update your plan. Try a smaller change, or ask again with more detail."
}
