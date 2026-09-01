import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

export async function requireAdmin() {
  const supabase = await createClient()
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) {
    redirect('/sign-in')
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('user_id, display_name, role')
    .eq('user_id', data.user.id)
    .maybeSingle()

  if (profile?.role !== 'admin') {
    redirect('/sign-in?error=not_admin')
  }

  return {
    supabase,
    user: data.user,
    profile: {
      userId: data.user.id,
      email: data.user.email ?? '',
      displayName: profile.display_name ?? data.user.email ?? 'Admin',
    },
  }
}
