import { createClient, SupabaseClient, User } from 'npm:@supabase/supabase-js@2'
import { json } from './cors.ts'

export function userClient(req: Request): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL')!
  const anon = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')
  const key = anon?.startsWith('{') ? JSON.parse(anon).default : anon
  return createClient(url, key!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  })
}

export function adminClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL')!
  const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEYS')
  const key = secret?.startsWith('{') ? JSON.parse(secret).default : secret
  return createClient(url, key!)
}

export async function requireUser(req: Request): Promise<{ user: User; supabase: SupabaseClient }> {
  const supabase = userClient(req)
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) {
    throw json({ error: 'Unauthorized' }, 401)
  }
  return { user: data.user, supabase }
}
