'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { Drawer } from '@/components/drawer'
import { formatNumber, formatWhen } from '@/lib/format'
import { createClient } from '@/lib/supabase/client'

export type MemberRow = {
  user_id: string
  email: string | null
  display_name: string | null
  onboarding_completed_at: string | null
  last_sign_in_at: string | null
  coach_calls: number
}

type Message = {
  id: string
  role: string
  content: { message?: string } | string | null
  created_at: string
}

type Detail = {
  age: number | null
  activity_level: string | null
  training_experience: string | null
  goal: string | null
  plan: string | null
  weight: number | null
  messages: Message[]
}

function messageText(content: Message['content']) {
  if (!content) return ''
  if (typeof content === 'string') return content
  if (typeof content.message === 'string') return content.message
  return JSON.stringify(content)
}

export function PeopleTable({ members }: { members: MemberRow[] }) {
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<MemberRow | null>(null)
  const [detail, setDetail] = useState<Detail | null>(null)

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault()
        document.getElementById('people-search')?.focus()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  useEffect(() => {
    if (!selected) {
      setDetail(null)
      return
    }
    let cancelled = false
    const member = selected
    const supabase = createClient()
    async function load() {
      const [{ data: profile }, { data: goal }, { data: metric }, { data: plan }, { data: conversations }] =
        await Promise.all([
          supabase.from('profiles').select('age, activity_level, training_experience').eq('user_id', member.user_id).maybeSingle(),
          supabase.from('fitness_goals').select('goal_type').eq('user_id', member.user_id).eq('is_active', true).maybeSingle(),
          supabase.from('body_metrics').select('weight_kg').eq('user_id', member.user_id).order('recorded_at', { ascending: false }).limit(1).maybeSingle(),
          supabase.from('workout_plans').select('name').eq('user_id', member.user_id).eq('status', 'active').maybeSingle(),
          supabase.from('ai_conversations').select('id').eq('user_id', member.user_id).order('updated_at', { ascending: false }).limit(1),
        ])
      const conversationId = conversations?.[0]?.id
      const { data: messages } = conversationId
        ? await supabase
            .from('ai_messages')
            .select('id, role, content, created_at')
            .eq('conversation_id', conversationId)
            .order('created_at', { ascending: false })
            .limit(5)
        : { data: [] }
      if (cancelled) return
      setDetail({
        age: profile?.age ?? null,
        activity_level: profile?.activity_level ?? null,
        training_experience: profile?.training_experience ?? null,
        goal: goal?.goal_type ?? null,
        plan: plan?.name ?? null,
        weight: metric?.weight_kg ?? null,
        messages: (messages ?? []) as Message[],
      })
    }
    load()
    return () => {
      cancelled = true
    }
  }, [selected])

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase()
    if (!needle) return members
    return members.filter((member) => {
      const haystack = `${member.display_name ?? ''} ${member.email ?? ''}`.toLowerCase()
      return haystack.includes(needle)
    })
  }, [members, query])

  return (
    <>
      <label className="block max-w-md">
        <span className="sr-only">Search people</span>
        <input
          id="people-search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Name or email"
          className="h-11 w-full rounded-lg border border-hairline bg-surface px-3"
        />
        <span className="mt-1 block text-[13px] text-muted">Command-K to search</span>
      </label>
      <div className="mt-6 overflow-x-auto">
        <table className="w-full min-w-[640px] text-left">
          <thead className="sticky top-0 bg-paper">
            <tr className="border-b border-hairline text-[13px] text-muted">
              <th className="py-3 font-medium">Name</th>
              <th className="py-3 font-medium">Email</th>
              <th className="py-3 font-medium">Onboarding</th>
              <th className="py-3 font-medium">Last seen</th>
              <th className="py-3 text-right font-medium">Coach calls</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((member) => (
              <tr
                key={member.user_id}
                className="cursor-pointer border-b border-hairline hover:bg-surface"
                onClick={() => setSelected(member)}
              >
                <td className="py-3 font-semibold">{member.display_name || '—'}</td>
                <td className="py-3">{member.email}</td>
                <td className="py-3">
                  <span className="rounded-full bg-surface px-2 py-1 text-[13px]">
                    {member.onboarding_completed_at ? 'Done' : 'In progress'}
                  </span>
                </td>
                <td className="py-3 text-muted">{formatWhen(member.last_sign_in_at)}</td>
                <td className="py-3 text-right tabular-nums">{formatNumber(Number(member.coach_calls))}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <Drawer title={selected?.display_name || selected?.email || 'Member'} open={Boolean(selected)} onClose={() => setSelected(null)}>
        {selected ? (
          <div className="space-y-6">
            <div>
              <p className="text-[17px]">{selected.email}</p>
              <p className="mt-1 text-[13px] text-muted">Last seen {formatWhen(selected.last_sign_in_at)}</p>
            </div>
            <dl className="space-y-2 text-[17px]">
              <DetailRow term="Goal" detail={detail?.goal ?? '—'} />
              <DetailRow term="Plan" detail={detail?.plan ?? '—'} />
              <DetailRow term="Age" detail={detail?.age ? String(detail.age) : '—'} />
              <DetailRow term="Weight" detail={detail?.weight ? `${detail.weight} kg` : '—'} />
              <DetailRow term="Experience" detail={detail?.training_experience ?? '—'} />
              <DetailRow term="Activity" detail={detail?.activity_level ?? '—'} />
            </dl>
            <div>
              <h3 className="text-[17px] font-semibold">Last coach messages</h3>
              <div className="mt-3 space-y-3">
                {(detail?.messages ?? []).map((message) => (
                  <div
                    key={message.id}
                    className={`max-w-[90%] rounded-2xl px-3 py-2 text-[16px] ${
                      message.role === 'user' ? 'ml-auto bg-accent text-white' : 'bg-paper'
                    }`}
                  >
                    {messageText(message.content) || '—'}
                  </div>
                ))}
              </div>
              <Link href="/coach" className="mt-4 inline-flex min-h-11 items-center text-[17px] font-semibold text-accent">
                View all coach activity
              </Link>
            </div>
          </div>
        ) : null}
      </Drawer>
    </>
  )
}

function DetailRow({ term, detail }: { term: string; detail: string }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-muted">{term}</dt>
      <dd className="text-right">{detail}</dd>
    </div>
  )
}
