'use client'

import { useState, useTransition } from 'react'
import { MODELS, READ_TOOLS, WRITE_TOOLS, isGpt56 } from '@/lib/tools'
import { saveModel, setCoachEnabled } from './actions'

export type ModelConfig = {
  id: string
  model: string
  temperature: number
  max_output_tokens: number
  daily_request_limit: number
  enabled: boolean
  enabled_tools: string[]
}

export function ModelForm({ config, promptVersion }: { config: ModelConfig; promptVersion: number | null }) {
  const [model, setModel] = useState(config.model)
  const [maxTokens, setMaxTokens] = useState(String(config.max_output_tokens))
  const [limit, setLimit] = useState(String(config.daily_request_limit))
  const [enabled, setEnabled] = useState(config.enabled)
  const [tools, setTools] = useState<string[]>(config.enabled_tools ?? [])
  const [message, setMessage] = useState('')
  const [pending, startTransition] = useTransition()

  function toggleTool(name: string) {
    setTools((current) => (current.includes(name) ? current.filter((item) => item !== name) : [...current, name]))
  }

  function handleEnabled(next: boolean) {
    setEnabled(next)
    startTransition(async () => {
      const result = await setCoachEnabled(config.id, next)
      setMessage(result.error ?? (next ? 'Coach enabled.' : 'Coach disabled.'))
    })
  }

  function handleSave(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    startTransition(async () => {
      const result = await saveModel({
        id: config.id,
        model,
        max_output_tokens: Number(maxTokens),
        daily_request_limit: Number(limit),
        enabled_tools: tools,
      })
      setMessage(result.error ?? 'Saved changes.')
    })
  }

  return (
    <form onSubmit={handleSave} className="max-w-xl space-y-6">
      <label className="flex items-center justify-between gap-4">
        <span>
          <span className="block text-[17px] font-semibold">Coach enabled</span>
          <span className="text-[13px] text-muted">Turns the kill switch immediately</span>
        </span>
        <input
          type="checkbox"
          className="h-6 w-11 accent-accent"
          checked={enabled}
          onChange={(event) => handleEnabled(event.target.checked)}
        />
      </label>

      <label className="flex flex-col gap-1">
        <span className="text-[13px] text-muted">Model</span>
        <select
          value={model}
          onChange={(event) => setModel(event.target.value)}
          className="h-11 rounded-lg border border-hairline bg-surface px-3"
        >
          {MODELS.map((item) => (
            <option key={item} value={item}>
              {item}
            </option>
          ))}
        </select>
        {isGpt56(model) ? (
          <span className="text-[13px] text-muted">Luna uses low reasoning; temperature is not sent.</span>
        ) : null}
      </label>

      <label className="flex flex-col gap-1">
        <span className="text-[13px] text-muted">Max output tokens</span>
        <input
          type="number"
          min={200}
          max={16000}
          value={maxTokens}
          onChange={(event) => setMaxTokens(event.target.value)}
          className="h-11 rounded-lg border border-hairline bg-surface px-3"
        />
      </label>

      <label className="flex flex-col gap-1">
        <span className="text-[13px] text-muted">Daily request limit</span>
        <input
          type="number"
          min={1}
          max={1000}
          value={limit}
          onChange={(event) => setLimit(event.target.value)}
          className="h-11 rounded-lg border border-hairline bg-surface px-3"
        />
      </label>

      <fieldset>
        <legend className="text-[17px] font-semibold">Enabled tools</legend>
        <div className="mt-3 grid gap-6 sm:grid-cols-2">
          <ToolGroup title="Read" names={READ_TOOLS} selected={tools} onToggle={toggleTool} />
          <ToolGroup title="Write" names={WRITE_TOOLS} selected={tools} onToggle={toggleTool} />
        </div>
      </fieldset>

      {promptVersion ? (
        <p className="text-[13px] text-muted">Prompt v{promptVersion} still names this model.</p>
      ) : null}
      {message ? <p className="text-[13px] text-muted">{message}</p> : null}

      <button
        type="submit"
        disabled={pending}
        className="h-11 rounded-lg bg-accent px-5 text-white hover:bg-accent-hover disabled:opacity-60"
      >
        {pending ? 'Saving…' : 'Save changes'}
      </button>
    </form>
  )
}

function ToolGroup({
  title,
  names,
  selected,
  onToggle,
}: {
  title: string
  names: readonly string[]
  selected: string[]
  onToggle: (name: string) => void
}) {
  return (
    <div>
      <p className="text-[13px] text-muted">{title}</p>
      <ul className="mt-2 space-y-2">
        {names.map((name) => (
          <li key={name}>
            <label className="flex min-h-11 items-center gap-2">
              <input
                type="checkbox"
                className="accent-accent"
                checked={selected.includes(name)}
                onChange={() => onToggle(name)}
              />
              <span className="text-[16px]">{name.replaceAll('_', ' ')}</span>
            </label>
          </li>
        ))}
      </ul>
    </div>
  )
}
