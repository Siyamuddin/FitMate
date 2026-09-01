import { requireAdmin } from '@/lib/require-admin'
import { countsByDay } from '@/lib/format'
import { Sparkline } from '@/components/sparkline'
import { CoachTable, type UsageRow } from './coach-table'

type Member = {
  user_id: string
  email: string | null
  display_name: string | null
}

export default async function CoachPage() {
  const { supabase } = await requireAdmin()
  const [{ data: usage }, { data: members }] = await Promise.all([
    supabase
      .from('ai_usage')
      .select('id, user_id, conversation_id, model, input_tokens, output_tokens, estimated_cost, created_at')
      .order('created_at', { ascending: false })
      .limit(200),
    supabase.rpc('admin_list_members'),
  ])

  const directory = new Map(
    ((members ?? []) as Member[]).map((member) => [member.user_id, member.display_name || member.email || 'Member']),
  )
  const rows: UsageRow[] = (usage ?? []).map((row) => ({
    ...row,
    member: directory.get(row.user_id) ?? 'Member',
  }))
  const spark = countsByDay(
    rows.map((row) => row.created_at),
    7,
  )

  return (
    <div>
      <h1 className="text-[34px] font-semibold tracking-[-0.4px] leading-[1.15]">Coach</h1>
      <p className="mt-2 text-[17px] text-muted">Inspection only. This is not a chat.</p>
      <section className="mt-8">
        <h2 className="text-[22px] font-semibold tracking-[-0.2px]">Tokens, 7 days</h2>
        <p className="mt-1 text-[13px] text-muted">Call count by day</p>
        <div className="mt-4 max-w-md">
          <Sparkline values={spark.map((item) => item.count)} label="Coach calls over 7 days" />
        </div>
      </section>
      <div className="mt-10">
        <CoachTable rows={rows} />
      </div>
    </div>
  )
}
