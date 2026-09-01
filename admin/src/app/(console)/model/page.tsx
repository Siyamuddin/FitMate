import { requireAdmin } from '@/lib/require-admin'
import { ModelForm, type ModelConfig } from './model-form'

export default async function ModelPage() {
  const { supabase } = await requireAdmin()
  const [{ data: config }, { data: prompt }] = await Promise.all([
    supabase.from('ai_configurations').select('*').limit(1).maybeSingle(),
    supabase.from('ai_prompt_versions').select('version, model').eq('is_active', true).maybeSingle(),
  ])

  if (!config) {
    return (
      <div>
        <h1 className="text-[34px] font-semibold tracking-[-0.4px]">Model</h1>
        <p className="mt-4 text-[17px] text-muted">No AI configuration row exists yet.</p>
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-[34px] font-semibold tracking-[-0.4px] leading-[1.15]">Model</h1>
      <p className="mt-2 max-w-xl text-[17px] text-muted">
        Changing the model does not rewrite the active prompt.
      </p>
      <div className="mt-8">
        <ModelForm
          config={{
            ...(config as ModelConfig),
            temperature: Number(config.temperature),
          }}
          promptVersion={prompt?.version ?? null}
        />
      </div>
    </div>
  )
}
