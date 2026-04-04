import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { MyApiClient } from '@/lib/clients/MyApiClient'
import { useFeatureFlag, useFeatureFlags } from '@/lib/hooks/use-feature-flags'

export const Route = createFileRoute('/demo/feature-flags')({
  component: FeatureFlagsDemo,
})

const client = new MyApiClient()

// ─── 1. Basic gate ────────────────────────────────────────────────────────────
// Render nothing (or an alternative) when the flag is off.
function ExampleBadge() {
  const isEnabled = useFeatureFlag('ExampleFlag')
  if (!isEnabled) return null
  return (
    <span className="inline-flex items-center rounded-full bg-primary px-2.5 py-0.5 text-xs font-medium text-primary-foreground">
      ExampleFlag Active
    </span>
  )
}

// ─── 2. Content switching ─────────────────────────────────────────────────────
// Swap entire UI sections based on a flag.
function CheckoutPanel() {
  const isNewCheckout = useFeatureFlag('ExampleFlag')

  if (isNewCheckout) {
    return (
      <div className="rounded-lg border border-green-500/30 bg-green-500/10 p-4">
        <p className="font-semibold text-green-700 dark:text-green-400">New Checkout (flag: ON)</p>
        <p className="text-sm text-muted-foreground mt-1">
          Streamlined multi-step checkout with express payment options.
        </p>
      </div>
    )
  }

  return (
    <div className="rounded-lg border border-muted bg-muted/30 p-4">
      <p className="font-semibold text-muted-foreground">Legacy Checkout (flag: OFF)</p>
      <p className="text-sm text-muted-foreground mt-1">
        Classic single-page checkout flow.
      </p>
    </div>
  )
}

// ─── 3. Class / style switching ───────────────────────────────────────────────
// Apply different Tailwind classes based on a flag.
function ThemedCard() {
  const isEnabled = useFeatureFlag('ExampleFlag')
  return (
    <div
      className={
        isEnabled
          ? 'rounded-lg border border-violet-500/40 bg-violet-950/30 p-4 text-violet-200'
          : 'rounded-lg border border-amber-400/40 bg-amber-50 p-4 text-amber-900'
      }
    >
      <p className="font-medium">
        {isEnabled ? '✓ ExampleFlag ON — alternate theme applied' : '✗ ExampleFlag OFF — default theme'}
      </p>
      <p className="text-sm opacity-70 mt-1">
        Background and text classes swap entirely based on the flag state.
      </p>
    </div>
  )
}

// ─── 4. Compound logic (AND / OR) ─────────────────────────────────────────────
function CompoundFlagPanel() {
  const isEnabled = useFeatureFlag('ExampleFlag')

  // Demonstrates the pattern — extend with additional flags as needed.
  const bothOn = isEnabled && isEnabled   // replace second isEnabled with another flag
  const eitherOn = isEnabled || false     // replace false with another flag

  return (
    <div className="space-y-2 text-sm">
      <div className="flex items-center gap-2">
        <FlagDot on={bothOn} />
        <span><code className="text-xs bg-muted px-1 rounded">FlagA AND FlagB</code> → {bothOn ? 'true' : 'false'}</span>
      </div>
      <div className="flex items-center gap-2">
        <FlagDot on={eitherOn} />
        <span><code className="text-xs bg-muted px-1 rounded">FlagA OR FlagB</code> → {eitherOn ? 'true' : 'false'}</span>
      </div>
    </div>
  )
}

// ─── 5. Full flags map ─────────────────────────────────────────────────────────
// Inspect every flag at once via useFeatureFlags().
function AllFlagsTable() {
  const flags = useFeatureFlags()
  const entries = Object.entries(flags)

  if (entries.length === 0) {
    return <p className="text-sm text-muted-foreground">Loading flags…</p>
  }

  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b text-left text-muted-foreground">
          <th className="pb-2 font-medium">Flag</th>
          <th className="pb-2 font-medium">Enabled</th>
        </tr>
      </thead>
      <tbody>
        {entries.map(([name, enabled]) => (
          <tr key={name} className="border-b last:border-0">
            <td className="py-2 font-mono">{name}</td>
            <td className="py-2">
              <FlagDot on={enabled} />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

// ─── 6. Variant service via BFF ───────────────────────────────────────────────
// The backend switches the entire ICheckoutService implementation based on the flag.
// This component shows what the server resolved — proving the variant pattern works.
function VariantServicePanel() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['checkout-variant'],
    queryFn: async () => {
      const [result] = await client.getCheckoutVariant()
      if (!result) throw new Error('Failed to load checkout variant')
      return result
    },
  })

  if (isLoading) return <p className="text-sm text-muted-foreground">Loading…</p>
  if (error || !data) return <p className="text-sm text-destructive">Error loading variant</p>

  return (
    <div className="space-y-1 text-sm">
      <div className="flex items-center gap-2">
        <span className="font-medium">Active variant:</span>
        <code className="rounded bg-muted px-1.5 py-0.5 text-xs">{data.variant}</code>
      </div>
      <p className="text-muted-foreground">{data.description}</p>
      <p className="text-xs text-muted-foreground/60">
        The server injected a different <code>ICheckoutService</code> implementation based on the
        ExampleFlag feature flag — no flag logic in the endpoint itself.
      </p>
    </div>
  )
}

// ─── 7. Loading state ─────────────────────────────────────────────────────────
// useFeatureFlag returns false while loading; useFeatureFlags returns {}.
// This panel shows how to handle the indeterminate state explicitly if needed.
function LoadingStatePanel() {
  const flags = useFeatureFlags()
  const loaded = Object.keys(flags).length > 0

  return (
    <div className="text-sm space-y-1">
      <p>
        <span className="font-medium">Flags loaded:</span>{' '}
        <FlagDot on={loaded} />
      </p>
      <p className="text-muted-foreground text-xs">
        <code>useFeatureFlag(name)</code> returns <code>false</code> (safe default) while the
        fetch is in-flight. <code>useFeatureFlags()</code> returns <code>{'{}'}</code>.
        No skeleton/loading guard needed in most cases.
      </p>
    </div>
  )
}

// ─── Shared helpers ───────────────────────────────────────────────────────────
function FlagDot({ on }: { on: boolean }) {
  return (
    <span
      className={`inline-block h-2.5 w-2.5 rounded-full ${on ? 'bg-green-500' : 'bg-red-400'}`}
      title={on ? 'enabled' : 'disabled'}
    />
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-xl border bg-card p-5 shadow-sm space-y-3">
      <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">{title}</h2>
      {children}
    </div>
  )
}

// ─── Page ─────────────────────────────────────────────────────────────────────
function FeatureFlagsDemo() {
  return (
    <main className="mx-auto max-w-2xl px-4 py-10 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Feature Flags Demo</h1>
        <p className="mt-1 text-muted-foreground text-sm">
          All patterns for consuming feature flags on the frontend.
        </p>
      </div>

      <Section title="1 · Basic gate — show / hide">
        <p className="text-sm text-muted-foreground">Render only when flag is on.</p>
        <ExampleBadge />
        <p className="text-xs text-muted-foreground">(badge appears only when ExampleFlag is enabled)</p>
      </Section>

      <Section title="2 · Content switching">
        <p className="text-sm text-muted-foreground">Swap entire UI blocks based on a flag.</p>
        <CheckoutPanel />
      </Section>

      <Section title="3 · Class / style switching">
        <p className="text-sm text-muted-foreground">Apply different Tailwind classes.</p>
        <ThemedCard />
      </Section>

      <Section title="4 · Compound logic">
        <p className="text-sm text-muted-foreground">Combine multiple flags with AND / OR.</p>
        <CompoundFlagPanel />
      </Section>

      <Section title="5 · All flags map">
        <p className="text-sm text-muted-foreground">
          <code>useFeatureFlags()</code> returns every flag at once.
        </p>
        <AllFlagsTable />
      </Section>

      <Section title="6 · Variant service (BFF)">
        <p className="text-sm text-muted-foreground">
          The server switches the entire <code>ICheckoutService</code> implementation based on the
          ExampleFlag flag. The endpoint knows nothing about the flag.
        </p>
        <VariantServicePanel />
      </Section>

      <Section title="7 · Loading state">
        <p className="text-sm text-muted-foreground">
          How flags behave while the initial fetch is in-flight.
        </p>
        <LoadingStatePanel />
      </Section>
    </main>
  )
}
