'use client'

import { useMemo, useState } from 'react'
import { Drawer } from '@/components/drawer'
import { formatCost, formatNumber, formatWhen } from '@/lib/format'
import { createClient } from '@/lib/supabase/client'

export type UsageRow = {
  id: string
  user_id: string
  conversation_id: string | null
  model: string
  input_tokens: number
  output_tokens: number
  estimated_cost: number | string | null
  created_at: string
  member: string
}

type Message = {
  id: string
  role: string
  content: { message?: string } | string | null
  created_at: string
}

function messageText(content: Message['content']) {
  if (!content) return ''
  if (typeof content === 'string') return content
  if (typeof content.message === 'string') return content.message
  return JSON.stringify(content)
}

export function CoachTable({ rows }: { rows: UsageRow[] }) {
  const [selected, setSelected] = useState<UsageRow | null>(null)
  const [messages, setMessages] = useState<Message[]>([])

  async function openRow(row: UsageRow) {
    setSelected(row)
    setMessages([])
    if (!row.conversation_id) return
    const supabase = createClient()
    const { data } = await supabase
      .from('ai_messages')
      .select('id, role, content, created_at')
      .eq('conversation_id', row.conversation_id)
      .order('created_at', { ascending: true })
      .limit(40)
    setMessages((data ?? []) as Message[])
  }

  const totals = useMemo(
    () =>
      rows.reduce(
        (sum, row) => ({
          input: sum.input + row.input_tokens,
          output: sum.output + row.output_tokens,
        }),
        { input: 0, output: 0 },
      ),
    [rows],
  )

  return (
    <>
      <p className="text-[13px] text-muted">
        {formatNumber(totals.input)} in · {formatNumber(totals.output)} out
      </p>
      <div className="mt-6 overflow-x-auto">
        <table className="w-full min-w-[720px] text-left">
          <thead className="sticky top-0 bg-paper">
            <tr className="border-b border-hairline text-[13px] text-muted">
              <th className="py-3 font-medium">When</th>
              <th className="py-3 font-medium">Member</th>
              <th className="py-3 font-medium">Model</th>
              <th className="py-3 text-right font-medium">Input</th>
              <th className="py-3 text-right font-medium">Output</th>
              <th className="py-3 text-right font-medium">Cost</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr
                key={row.id}
                className="cursor-pointer border-b border-hairline hover:bg-surface"
                onClick={() => openRow(row)}
              >
                <td className="py-3">{formatWhen(row.created_at)}</td>
                <td className="py-3">{row.member}</td>
                <td className="py-3">{row.model}</td>
                <td className="py-3 text-right tabular-nums">{formatNumber(row.input_tokens)}</td>
                <td className="py-3 text-right tabular-nums">{formatNumber(row.output_tokens)}</td>
                <td className="py-3 text-right tabular-nums">{formatCost(row.estimated_cost)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <Drawer title={selected?.member ?? 'Conversation'} open={Boolean(selected)} onClose={() => setSelected(null)}>
        <div className="space-y-3">
          {messages.length === 0 ? (
            <p className="text-[17px] text-muted">No messages on this call.</p>
          ) : (
            messages.map((message) => (
              <div
                key={message.id}
                className={`max-w-[90%] rounded-2xl px-3 py-2 text-[16px] ${
                  message.role === 'user' ? 'ml-auto bg-accent text-white' : 'bg-paper'
                }`}
              >
                {messageText(message.content) || '—'}
              </div>
            ))
          )}
        </div>
      </Drawer>
    </>
  )
}
