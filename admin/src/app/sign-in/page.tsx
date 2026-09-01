import { Suspense } from 'react'
import { SignInForm } from './sign-in-form'

export default function SignInPage() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center px-6 py-16">
      <p className="text-[13px] tracking-wide text-muted">FitMate</p>
      <h1 className="mt-2 text-[34px] font-semibold tracking-[-0.4px] leading-[1.15]">Admin</h1>
      <p className="mt-2 text-[17px] text-muted">Sign in with an admin account.</p>
      <div className="mt-10">
        <Suspense>
          <SignInForm />
        </Suspense>
      </div>
    </main>
  )
}
