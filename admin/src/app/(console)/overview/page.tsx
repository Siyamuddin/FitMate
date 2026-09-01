import Link from 'next/link'
import { requireAdmin } from '@/lib/require-admin'
import { countsByDay, formatDay, formatNumber, formatWhen } from '@/lib/format'
import { Sparkline } from '@/components/sparkline'

type Member = {
  user_id: string
  email: string | null
  display_name: string | null
  last_sign_in_at: string | null
  onboarding_completed_at: string | null
}

type Config = {
  model: string
  daily_request_limit: number
  enabled: boolean
}

type Prompt = {
  version: number
}

export default async function OverviewPage() {
  const { supabase } = await requireAdmin()
  const [{ data: members }, { data: usage }, { data: config }, { data: prompt }] = await Promise.all([
    supabase.rpc('admin_list_members'),
    supabase.from('ai_usage').select('created_at, input_tokens, output_tokens'),
    supabase.from('ai_configurations').select('model, daily_request_limit, enabled').limit(1).maybeSingle(),
    supabase.from('ai_prompt_versions').select('version').eq('is_active', true).maybeSingle(),
  ])

  const people = (members ?? []) as Member[]
  const calls = usage ?? []
  const day = new Date()
  day.setHours(0, 0, 0, 0)
  const since = new Date(day.getTime() - 13 * 24 * 60 * 60 * 1000)
  const last24h = Date.now() - 24 * 60 * 60 * 1000
  const calls24h = calls.filter((row) => new Date(row.created_at).getTime() >= last24h)
  const tokens24h = calls24h.reduce((sum, row) => sum + (row.input_tokens ?? 0) + (row.output_tokens ?? 0), 0)
  const spark = countsByDay(
    calls.map((row) => row.created_at).filter((stamp) => new Date(stamp) >= since),
    14,
  )
  const live = config as Config | null
  const activePrompt = prompt as Prompt | null

  return (
    <div>
      <p className="text-[13px] text-muted">{formatDay()}</p>
      <h1 className="mt-1 text-[34px] font-semibold tracking-[-0.4px] leading-[1.15]">Overview</h1>

      <section className="mt-8 grid grid-cols-2 gap-x-8 gap-y-6 border-b border-hairline pb-8 lg:grid-cols-4">
        <Kpi label="Members" value={formatNumber(people.length)} />
        <Kpi
          label="Onboarded"
          value={formatNumber(people.filter((member) => member.onboarding_completed_at).length)}
        />
        <Kpi label="Coach calls (24h)" value={formatNumber(calls24h.length)} />
        <Kpi label="Tokens (24h)" value={formatNumber(tokens24h)} />
      </section>

      <div className="mt-8 grid gap-10 lg:grid-cols-[1fr_280px]">
        <section>
          <h2 className="text-[22px] font-semibold tracking-[-0.2px]">Coach calls, 14 days</h2>
          <p className="mt-1 text-[13px] text-muted">Daily count from ai_usage</p>
          <div className="mt-4">
            <Sparkline values={spark.map((item) => item.count)} label="Coach calls over 14 days" />
          </div>
        </section>
        <aside className="rounded-2xl bg-surface p-5">
          <p className="text-[13px] text-muted">Live coach</p>
          <p className="mt-2 text-[22px] font-semibold tracking-[-0.2px]">{live?.model ?? '—'}</p>
          <dl className="mt-4 space-y-2 text-[17px]">
            <Row term="Prompt" detail={activePrompt ? `v${activePrompt.version}` : 'None'} />
            <Row term="Daily limit" detail={live ? String(live.daily_request_limit) : '—'} />
            <Row term="Status" detail={live?.enabled === false ? 'Disabled' : 'Enabled'} />
          </dl>
          <Link href="/model" className="mt-5 inline-flex min-h-11 items-center text-[17px] font-semibold text-accent">
            Edit model
          </Link>
        </aside>
      </div>

      <section className="mt-12">
        <h2 className="text-[22px] font-semibold tracking-[-0.2px]">Recent members</h2>
        <ul className="mt-4 divide-y divide-hairline">
          {people.slice(0, 6).map((member) => (
            <li key={member.user_id} className="flex items-baseline justify-between gap-4 py-3">
              <div>
                <p className="text-[17px] font-semibold">{member.display_name || member.email}</p>
                <p className="text-[13px] text-muted">{member.email}</p>
              </div>
              <p className="text-[13px] text-muted">{formatWhen(member.last_sign_in_at)}</p>
            </li>
          ))}
        </ul>
      </section>
    </div>
  )
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-[13px] text-muted">{label}</p>
      <p className="mt-1 text-[34px] font-semibold tracking-[-0.4px]">{value}</p>
    </div>
  )
}

function Row({ term, detail }: { term: string; detail: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4">
      <dt className="text-muted">{term}</dt>
      <dd>{detail}</dd>
    </div>
  )
}
