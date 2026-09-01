'use client'

import { useEffect } from 'react'

export function Drawer({
  title,
  open,
  onClose,
  children,
}: {
  title: string
  open: boolean
  onClose: () => void
  children: React.ReactNode
}) {
  useEffect(() => {
    if (!open) return
    function onKey(event: KeyboardEvent) {
      if (event.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null

  return (
    <div className="fixed inset-0 z-40 flex justify-end">
      <button
        type="button"
        aria-label="Close"
        className="h-full flex-1 bg-ink/20"
        onClick={onClose}
      />
      <aside className="flex h-full w-full max-w-[400px] flex-col bg-surface">
        <div className="flex items-center justify-between border-b border-hairline px-5 py-4">
          <h2 className="text-[22px] font-semibold tracking-[-0.2px]">{title}</h2>
          <button type="button" onClick={onClose} className="min-h-11 text-[17px] text-muted">
            Close
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-5">{children}</div>
      </aside>
    </div>
  )
}
