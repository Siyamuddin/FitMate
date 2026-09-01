import { requireAdmin } from '@/lib/require-admin'
import { PeopleTable, type MemberRow } from './people-table'

export default async function PeoplePage() {
  const { supabase } = await requireAdmin()
  const { data } = await supabase.rpc('admin_list_members')
  const members = (membersSafe(data) ?? []) as MemberRow[]

  return (
    <div>
      <h1 className="text-[34px] font-semibold tracking-[-0.4px] leading-[1.15]">People</h1>
      <p className="mt-2 text-[17px] text-muted">{members.length} members</p>
      <div className="mt-8">
        <PeopleTable members={members} />
      </div>
    </div>
  )
}

function membersSafe(data: unknown) {
  return Array.isArray(data) ? data : []
}
