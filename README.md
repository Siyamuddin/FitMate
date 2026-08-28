# FitMate

iOS-first AI fitness coaching. Flutter talks to Supabase Auth, Postgres, and Storage. OpenAI runs only in Edge Functions.

## Local setup

1. Start Docker Desktop.
2. From this repo:

```bash
supabase start
```

3. Copy the printed `API URL` and `anon key` into `.env`:

```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=<anon-or-publishable-key>
```

4. Put `OPENAI_API_KEY` in `supabase/functions/.env` (never in Flutter).
5. Run the app:

```bash
flutter run
```

Serve functions locally when you need AI:

```bash
supabase functions serve generate-plan,coach-chat,apply-ai-action --env-file supabase/functions/.env
```

## Product loop

Onboard → generate plan → train and log food → track weight → coach proposes changes → you Apply or Dismiss.

Tabs: Home, Workout, Nutrition, Coach, Progress. Profile is pushed from Home.

## Security

- Flutter uses the anon/publishable key only.
- Edge Functions use the user JWT for user data and the service role only for `ai_prompt_versions`, `ai_configurations`, and `ai_usage`.
- Do not reuse other Supabase projects. A dedicated FitMate cloud project is created later after cost confirmation.
