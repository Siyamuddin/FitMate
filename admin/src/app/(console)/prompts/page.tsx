import { requireAdmin } from '@/lib/require-admin'
import { PromptsEditor, type PromptVersion } from './prompts-editor'

export default async function PromptsPage() {
  const { supabase } = await requireAdmin()
  const [{ data: versions }, { data: config }] = await Promise.all([
    supabase.from('ai_prompt_versions').select('*').order('version', { ascending: false }),
    supabase.from('ai_configurations').select('model').limit(1).maybeSingle(),
  ])

  return (
    <div>
      <h1 className="text-[34px] font-semibold tracking-[-0.4px] leading-[1.15]">Prompts</h1>
      <p className="mt-2 max-w-2xl text-[17px] text-muted">
        The system prompt is the coach’s beliefs. Coach and plan instructions are the user prompts sent with each request.
      </p>
      <div className="mt-8">
        <PromptsEditor versions={(versions ?? []) as PromptVersion[]} liveModel={config?.model ?? 'gpt-5.6-luna'} />
      </div>
    </div>
  )
}
