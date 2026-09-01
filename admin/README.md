# FitMate Admin

Internal console for members, coaching usage, model settings, and prompts.

## Local

```bash
cd admin
cp .env.example .env.local
# set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
npm run dev
```

Sign in with an account whose `profiles.role` is `admin`.
