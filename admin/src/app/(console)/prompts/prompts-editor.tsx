'use client'

import { useMemo, useState, useTransition } from 'react'
import { CONTEXT_SHAPE } from '@/lib/tools'
import { createPromptVersion, publishPrompt } from './actions'

export type PromptVersion = {
  id: string
  version: number
  system_prompt: string
  coach_instruction: string | null
  plan_instruction: string | null
  model: string
  is_active: boolean
  created_at: string
}

export function PromptsEditor({ versions, liveModel }: { versions: PromptVersion[]; liveModel: string }) {
  const active = versions.find((item) => item.is_active) ?? versions[0]
  const [selectedId, setSelectedId] = useState(active?.id ?? '')
  const selected = versions.find((item) => item.id === selectedId) ?? active
  const [system, setSystem] = useState(active?.system_prompt ?? '')
  const [coach, setCoach] = useState(active?.coach_instruction ?? '')
  const [plan, setPlan] = useState(active?.plan_instruction ?? '')
  const [showContext, setShowContext] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [message, setMessage] = useState('')
  const [pending, startTransition] = useTransition()

  const dirty = useMemo(() => {
    if (!selected) return false
    return (
      system !== selected.system_prompt ||
      coach !== (selected.coach_instruction ?? '') ||
      plan !== (selected.plan_instruction ?? '')
    )
  }, [selected, system, coach, plan])

  function loadVersion(version: PromptVersion) {
    setSelectedId(version.id)
    setSystem(version.system_prompt)
    setCoach(version.coach_instruction ?? '')
    setPlan(version.plan_instruction ?? '')
    setMessage('')
  }

  function save(publish: boolean) {
    startTransition(async () => {
      const result = await createPromptVersion({
        system_prompt: system,
        coach_instruction: coach,
        plan_instruction: plan,
        model: liveModel,
        publish,
      })
      setConfirmOpen(false)
      setMessage(result.error ?? (publish ? `Published v${result.version}.` : `Saved draft v${result.version}.`))
    })
  }

  function handlePublishExisting() {
    if (!selected) return
    startTransition(async () => {
      const result = await publishPrompt(selected.id)
      setMessage(result.error ?? `Published v${selected.version}.`)
    })
  }

  return (
    <div className="grid gap-8 lg:grid-cols-[220px_1fr]">
      <aside>
        <button
          type="button"
          className="min-h-11 text-left text-[17px] font-semibold text-accent"
          onClick={() => {
            if (active) loadVersion(active)
          }}
        >
          New version
        </button>
        <ul className="mt-4 space-y-1">
          {versions.map((version) => (
            <li key={version.id}>
              <button
                type="button"
                onClick={() => loadVersion(version)}
                className={`flex min-h-11 w-full items-center justify-between rounded-lg px-3 text-left ${
                  selectedId === version.id ? 'bg-surface font-semibold' : 'text-muted'
                }`}
              >
                <span>v{version.version}</span>
                {version.is_active ? <span className="text-[13px] text-accent">Active</span> : null}
              </button>
            </li>
          ))}
        </ul>
      </aside>

      <div className="space-y-5">
        <label className="flex flex-col gap-1">
          <span className="text-[13px] text-muted">System prompt</span>
          <textarea
            value={system}
            onChange={(event) => setSystem(event.target.value)}
            rows={12}
            className="rounded-lg border border-hairline bg-surface px-3 py-3"
          />
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-[13px] text-muted">Coach instruction</span>
          <textarea
            value={coach}
            onChange={(event) => setCoach(event.target.value)}
            rows={4}
            className="rounded-lg border border-hairline bg-surface px-3 py-3"
          />
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-[13px] text-muted">Plan instruction</span>
          <textarea
            value={plan}
            onChange={(event) => setPlan(event.target.value)}
            rows={4}
            className="rounded-lg border border-hairline bg-surface px-3 py-3"
          />
        </label>

        <button
          type="button"
          className="text-left text-[17px] text-muted"
          onClick={() => setShowContext((value) => !value)}
        >
          {showContext ? 'Hide' : 'Show'} what the model receives
        </button>
        {showContext ? (
          <pre className="overflow-x-auto rounded-lg bg-surface p-4 text-[13px] text-muted">{CONTEXT_SHAPE}</pre>
        ) : null}

        {message ? <p className="text-[13px] text-muted">{message}</p> : null}

        <div className="flex flex-wrap gap-3">
          <button
            type="button"
            disabled={pending || !dirty}
            onClick={() => setConfirmOpen(true)}
            className="h-11 rounded-lg bg-accent px-5 text-white hover:bg-accent-hover disabled:opacity-60"
          >
            Save as new version
          </button>
          {selected && !selected.is_active && !dirty ? (
            <button
              type="button"
              disabled={pending}
              onClick={handlePublishExisting}
              className="h-11 text-[17px] text-accent"
            >
              Publish this version
            </button>
          ) : null}
        </div>
      </div>

      {confirmOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/30 px-5">
          <div role="dialog" aria-modal="true" className="w-full max-w-md rounded-2xl bg-surface p-6">
            <h2 className="text-[22px] font-semibold">Publish now?</h2>
            <p className="mt-2 text-[17px] text-muted">
              Saving always creates a new version. Publishing makes it the live coach prompt.
            </p>
            <div className="mt-6 flex justify-end gap-3">
              <button type="button" className="min-h-11 px-3 text-muted" onClick={() => save(false)}>
                Save draft
              </button>
              <button
                type="button"
                className="h-11 rounded-lg bg-accent px-5 text-white"
                onClick={() => save(true)}
              >
                Publish now
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}
