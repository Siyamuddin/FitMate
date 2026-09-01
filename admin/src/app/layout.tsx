import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'FitMate Admin',
  description: 'Internal console for FitMate members, coaching, and prompts.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-full bg-paper text-ink antialiased">{children}</body>
    </html>
  )
}
