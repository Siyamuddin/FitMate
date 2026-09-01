import { requireAdmin } from '@/lib/require-admin'
import { Shell } from '@/components/shell'

export default async function ConsoleLayout({ children }: { children: React.ReactNode }) {
  const { profile } = await requireAdmin()
  return (
    <Shell name={profile.displayName} email={profile.email}>
      {children}
    </Shell>
  )
}
