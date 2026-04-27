import { createFileRoute, Link } from '@tanstack/react-router'
import { useFeatureFlags } from '@/shared/hooks/use-feature-flags'

export const Route = createFileRoute('/')({ component: HomePage })

function HomePage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-100">
      <div className="mx-auto max-w-3xl px-6 py-16 space-y-12">
        <Hero />
        <FeatureFlagsStatus />
        <Stack />
      </div>
    </main>
  )
}

function Hero() {
  return (
    <section className="space-y-4">
      <h1 className="text-4xl font-bold tracking-tight">Your project starts here.</h1>
      <p className="text-slate-400 text-lg leading-relaxed">
        This is a clean starting point built on{' '}
        <span className="text-slate-200 font-medium">.NET 10</span>,{' '}
        <span className="text-slate-200 font-medium">FastEndpoints</span>,{' '}
        <span className="text-slate-200 font-medium">Aspire</span>, and{' '}
        <span className="text-slate-200 font-medium">TanStack Router</span>.
        Delete this page and start building.
      </p>
      <p className="text-slate-500 text-sm">
        Edit{' '}
        <code className="rounded bg-slate-800 px-1.5 py-0.5 text-slate-300">
          src/routes/index.tsx
        </code>{' '}
        to get started.
      </p>
    </section>
  )
}

function FeatureFlagsStatus() {
  const flags = useFeatureFlags()
  const entries = Object.entries(flags)

  return (
    <section className="rounded-xl border border-slate-800 bg-slate-900 p-6 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-400">
            Feature Flags
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">Live from the API — backend is connected.</p>
        </div>
        <Link
          to="/demo/feature-flags"
          className="text-xs text-slate-400 hover:text-slate-200 underline underline-offset-4 transition-colors"
        >
          View all patterns →
        </Link>
      </div>

      {entries.length === 0 ? (
        <p className="text-sm text-slate-500">Loading flags…</p>
      ) : (
        <ul className="space-y-2">
          {entries.map(([name, enabled]) => (
            <li key={name} className="flex items-center gap-3 text-sm">
              <span
                className={`h-2 w-2 rounded-full shrink-0 ${enabled ? 'bg-emerald-500' : 'bg-slate-600'}`}
              />
              <span className="font-mono text-slate-300">{name}</span>
              <span className={`ml-auto text-xs ${enabled ? 'text-emerald-400' : 'text-slate-500'}`}>
                {enabled ? 'on' : 'off'}
              </span>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

function Stack() {
  const items = [
    { label: 'Backend', value: '.NET 10 · FastEndpoints · EF Core · Aspire' },
    { label: 'Frontend', value: 'React 19 · TanStack Router · TanStack Query · Tailwind v4' },
    { label: 'API client', value: 'Auto-generated via npx apx-gen from OpenAPI spec' },
    { label: 'Rendering', value: 'SPA (static files) — deployable to SWA or any CDN' },
  ]

  return (
    <section className="space-y-3">
      <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-400">Stack</h2>
      <dl className="divide-y divide-slate-800 rounded-xl border border-slate-800 overflow-hidden">
        {items.map(({ label, value }) => (
          <div key={label} className="flex gap-4 px-4 py-3 text-sm bg-slate-900">
            <dt className="w-28 shrink-0 text-slate-500">{label}</dt>
            <dd className="text-slate-300">{value}</dd>
          </div>
        ))}
      </dl>
    </section>
  )
}
