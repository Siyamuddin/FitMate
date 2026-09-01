'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

const NAV = [
  { href: '/overview', label: 'Overview' },
  { href: '/people', label: 'People' },
  { href: '/coach', label: 'Coach' },
  { href: '/model', label: 'Model' },
  { href: '/prompts', label: 'Prompts' },
]

export function Shell({
  children,
  name,
  email,
}: {
  children: React.ReactNode
  name: string
  email: string
}) {
  const pathname = usePathname()

  return (
    <div className="min-h-screen lg:grid lg:grid-cols-[220px_1fr]">
      <aside className="border-b border-hairline bg-paper lg:border-b-0 lg:border-r">
        <div className="flex h-full flex-col px-5 py-6">
          <p className="text-[13px] text-muted">FitMate</p>
          <p className="text-[22px] font-semibold tracking-[-0.2px]">Admin</p>
          <nav className="mt-8 flex gap-1 overflow-x-auto lg:flex-col lg:overflow-visible" aria-label="Primary">
            {NAV.map((item) => {
              const active = pathname === item.href || pathname.startsWith(`${item.href}/`)
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`min-h-11 whitespace-nowrap rounded-lg px-3 py-2 text-[17px] ${
                    active ? 'bg-surface font-semibold text-ink' : 'text-muted hover:text-ink'
                  }`}
                >
                  {item.label}
                </Link>
              )
            })}
          </nav>
          <div className="mt-8 hidden lg:mt-auto lg:block">
            <p className="truncate text-[17px] font-semibold">{name}</p>
            <p className="truncate text-[13px] text-muted">{email}</p>
            <form action="/sign-out" method="post">
              <button type="submit" className="mt-3 min-h-11 text-left text-[17px] text-muted hover:text-ink">
                Sign out
              </button>
            </form>
          </div>
        </div>
      </aside>
      <div className="min-w-0">
        <div className="flex items-center justify-between border-b border-hairline px-5 py-3 lg:hidden">
          <p className="truncate text-[13px] text-muted">{email}</p>
          <form action="/sign-out" method="post">
            <button type="submit" className="min-h-11 text-[17px] text-muted">
              Sign out
            </button>
          </form>
        </div>
        <main className="mx-auto w-full max-w-6xl px-5 py-8 lg:px-10 lg:py-10">{children}</main>
      </div>
    </div>
  )
}
