'use client'

import { useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export function SignInForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState(searchParams.get('error') === 'not_admin' ? 'This account is not an admin.' : '')
  const [pending, setPending] = useState(false)

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setPending(true)
    setError('')
    const supabase = createClient()
    const { data, error: signInError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    })
    if (signInError || !data.user) {
      setPending(false)
      setError('Email or password is incorrect.')
      return
    }
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('user_id', data.user.id)
      .maybeSingle()
    if (profile?.role !== 'admin') {
      await supabase.auth.signOut()
      setPending(false)
      setError('This account is not an admin.')
      return
    }
    router.replace('/overview')
    router.refresh()
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <label className="flex flex-col gap-1">
        <span className="text-[13px] text-muted">Email</span>
        <input
          type="email"
          autoComplete="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className="h-11 rounded-lg border border-hairline bg-surface px-3"
          required
        />
      </label>
      <label className="flex flex-col gap-1">
        <span className="text-[13px] text-muted">Password</span>
        <input
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          className="h-11 rounded-lg border border-hairline bg-surface px-3"
          required
        />
      </label>
      {error ? <p className="text-[13px] text-danger">{error}</p> : null}
      <button
        type="submit"
        disabled={pending}
        className="h-11 rounded-lg bg-accent text-white hover:bg-accent-hover disabled:opacity-60"
      >
        {pending ? 'Signing in…' : 'Sign in'}
      </button>
    </form>
  )
}
