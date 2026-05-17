import { createFileRoute, Link } from '@tanstack/react-router'
import { useFeatureFlags } from '@/shared/hooks/use-feature-flags'
import { useAuth } from '@/shared/auth/AuthContext'

export const Route = createFileRoute('/')({ component: HomePage })

function HomePage() {
  return (
    <main className="relative min-h-screen bg-[#020208] text-slate-100 overflow-hidden">
      {/* Dot-grid texture */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          backgroundImage:
            'radial-gradient(circle, rgba(148,163,184,0.06) 1px, transparent 1px)',
          backgroundSize: '28px 28px',
        }}
        aria-hidden
      />

      {/* Aurora glow blobs */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
        <div className="absolute -top-[15%] left-[5%] w-[650px] h-[650px] rounded-full bg-indigo-600 opacity-[0.14] blur-[130px] animate-[aurora_10s_ease-in-out_infinite]" />
        <div className="absolute top-[20%] -right-[8%] w-[520px] h-[520px] rounded-full bg-violet-500 opacity-[0.11] blur-[120px] animate-[aurora_13s_ease-in-out_infinite_2s]" />
        <div className="absolute bottom-[-5%] left-[25%] w-[480px] h-[480px] rounded-full bg-cyan-500 opacity-[0.09] blur-[110px] animate-[aurora_11s_ease-in-out_infinite_4s]" />
        <div className="absolute top-[55%] -left-[5%] w-[320px] h-[320px] rounded-full bg-fuchsia-600 opacity-[0.08] blur-[90px] animate-[aurora_9s_ease-in-out_infinite_1s]" />
        <div className="absolute top-[40%] left-[40%] w-[200px] h-[200px] rounded-full bg-sky-400 opacity-[0.06] blur-[70px] animate-[aurora_15s_ease-in-out_infinite_6s]" />
      </div>

      <div className="relative mx-auto max-w-4xl px-6 py-20 flex flex-col gap-14">
        <Hero />

        {/* Separator */}
        <div className="w-full h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />

        {/* Bento grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <div className="lg:col-span-2">
            <AuthCard />
          </div>
          <FeatureFlagsCard />
        </div>

        <StackSection />
      </div>
    </main>
  )
}

/* ── Gradient-border card wrapper ─────────────────────────────── */
function GlassCard({
  children,
  className = '',
  accentFrom = 'from-white/20',
  accentTo = 'to-transparent',
}: {
  children: React.ReactNode
  className?: string
  accentFrom?: string
  accentTo?: string
}) {
  return (
    <div
      className={`relative rounded-2xl p-px bg-gradient-to-br ${accentFrom} via-white/5 ${accentTo} transition-all duration-500 hover:shadow-[0_0_50px_rgba(99,102,241,0.12)] ${className}`}
    >
      <div className="rounded-2xl bg-[#07070f]/90 backdrop-blur-xl p-6 h-full">
        {children}
      </div>
    </div>
  )
}

/* ── Hero ─────────────────────────────────────────────────────── */
function Hero() {
  return (
    <section className="space-y-7">
      {/* Badge */}
      <div className="inline-flex rounded-full p-px bg-gradient-to-r from-indigo-500 via-violet-500 to-cyan-400 animate-[float_4s_ease-in-out_infinite]">
        <div className="rounded-full bg-[#020208] px-4 py-1.5 flex items-center gap-2.5">
          <span className="relative flex h-1.5 w-1.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-indigo-400 opacity-75" />
            <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-indigo-300" />
          </span>
          <span className="text-xs text-slate-300 font-medium tracking-wide">
            Full-stack scaffold · .NET 10 · React 19
          </span>
        </div>
      </div>

      {/* Headline */}
      <h1 className="text-6xl sm:text-7xl font-black tracking-tighter leading-[0.92]">
        <span className="block bg-[linear-gradient(130deg,_#ffffff_0%,_#e2e8f0_35%,_#c4b5fd_65%,_#a78bfa_100%)] bg-clip-text text-transparent">
          Your project
        </span>
        <span className="block bg-[linear-gradient(130deg,_#818cf8_0%,_#a78bfa_35%,_#67e8f9_75%,_#38bdf8_100%)] bg-clip-text text-transparent">
          starts here.
        </span>
      </h1>

      {/* Subtitle */}
      <p className="text-slate-400 text-xl leading-relaxed max-w-2xl">
        Comes with{' '}
        <span className="text-indigo-300 font-semibold drop-shadow-[0_0_10px_rgba(129,140,248,0.6)]">
          auth
        </span>
        ,{' '}
        <span className="text-violet-300 font-semibold drop-shadow-[0_0_10px_rgba(167,139,250,0.6)]">
          feature flags
        </span>
        ,{' '}
        <span className="text-cyan-300 font-semibold drop-shadow-[0_0_10px_rgba(103,232,249,0.6)]">
          observability
        </span>
        ,{' '}
        <span className="text-fuchsia-300 font-semibold drop-shadow-[0_0_10px_rgba(240,171,252,0.6)]">
          CI/CD
        </span>
        , and a generated API client. Delete this page and build something.
      </p>

      {/* Terminal hint */}
      <div className="inline-flex items-center gap-2 rounded-lg border border-white/8 bg-white/[0.025] px-3.5 py-2">
        <span className="text-slate-600 font-mono text-sm select-none">$</span>
        <span className="text-slate-500 font-mono text-sm">edit</span>
        <span className="text-indigo-400 font-mono text-sm">
          src/routes/index.tsx
        </span>
        <span className="ml-1 inline-block h-4 w-px bg-indigo-400/70 animate-pulse" />
      </div>
    </section>
  )
}

/* ── Auth card ────────────────────────────────────────────────── */
function AuthCard() {
  const { user, isAuthenticated, isLoading } = useAuth()

  return (
    <GlassCard accentFrom="from-indigo-500/30" accentTo="to-violet-500/5">
      <div className="flex items-start justify-between mb-5">
        <div className="space-y-0.5">
          <h2 className="text-[10px] font-bold uppercase tracking-[0.2em] text-indigo-400">
            Auth
          </h2>
          <p className="text-xs text-slate-600">OpenIddict · ASP.NET Core Identity · PKCE</p>
        </div>
        <div className="flex items-center gap-1.5">
          <span
            className={`h-2 w-2 rounded-full ${isAuthenticated ? 'bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.8)]' : 'bg-slate-700'}`}
          />
          <span className={`text-xs ${isAuthenticated ? 'text-emerald-400' : 'text-slate-600'}`}>
            {isAuthenticated ? 'authenticated' : 'not signed in'}
          </span>
        </div>
      </div>

      {isLoading ? (
        <div className="flex items-center gap-2 text-sm text-slate-600">
          <span className="h-1 w-12 rounded-full bg-slate-800 animate-pulse" />
          <span className="h-1 w-20 rounded-full bg-slate-800 animate-pulse" />
        </div>
      ) : isAuthenticated && user ? (
        <div className="space-y-3">
          <div className="flex items-center gap-3">
            <div className="h-9 w-9 rounded-full bg-gradient-to-br from-indigo-500 to-violet-600 flex items-center justify-center text-sm font-bold text-white shrink-0">
              {(user.email ?? user.sub).charAt(0).toUpperCase()}
            </div>
            <div>
              <p className="text-sm font-medium text-slate-200">{user.email ?? user.sub}</p>
              <p className="text-xs text-slate-500">{user.roles.join(' · ')}</p>
            </div>
          </div>
          <Link
            to="/demo/protected"
            className="inline-flex items-center gap-1.5 text-xs text-indigo-400 hover:text-indigo-300 transition-colors"
          >
            View protected route
            <span className="text-indigo-600">→</span>
          </Link>
        </div>
      ) : (
        <div className="space-y-4">
          <p className="text-sm text-slate-500 leading-snug">
            Use the{' '}
            <span className="text-slate-300 font-medium">dev login panel</span>{' '}
            <span className="text-slate-600">(bottom-left)</span> to sign in with a seeded account.
          </p>
          <div className="grid grid-cols-2 gap-2">
            {['user@localhost', 'admin@localhost'].map((email) => (
              <div
                key={email}
                className="rounded-lg border border-white/6 bg-white/[0.02] px-3 py-2"
              >
                <p className="text-xs font-mono text-slate-500">{email}</p>
                <p className="text-[10px] text-slate-700 mt-0.5">DevPass1!</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </GlassCard>
  )
}

/* ── Feature flags card ───────────────────────────────────────── */
function FeatureFlagsCard() {
  const flags = useFeatureFlags()
  const entries = Object.entries(flags)

  return (
    <GlassCard accentFrom="from-violet-500/25" accentTo="to-fuchsia-500/5">
      <div className="flex items-start justify-between mb-5">
        <div className="space-y-0.5">
          <h2 className="text-[10px] font-bold uppercase tracking-[0.2em] text-violet-400">
            Feature Flags
          </h2>
          <div className="flex items-center gap-1.5">
            <span className="relative flex h-1.5 w-1.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-violet-400 opacity-75" />
              <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-violet-400" />
            </span>
            <span className="text-[10px] text-slate-600">live from API</span>
          </div>
        </div>
        <Link
          to="/demo/feature-flags"
          className="text-[10px] text-slate-600 hover:text-violet-300 transition-colors"
        >
          all patterns →
        </Link>
      </div>

      {entries.length === 0 ? (
        <div className="space-y-2">
          {[60, 40, 80].map((w) => (
            <div key={w} className={`h-6 w-${w} rounded-full bg-white/[0.04] animate-pulse`} />
          ))}
        </div>
      ) : (
        <ul className="space-y-2">
          {entries.map(([name, enabled]) => (
            <li key={name}>
              <div
                className={`flex items-center gap-2.5 rounded-lg border px-3 py-2 transition-colors ${
                  enabled
                    ? 'border-emerald-500/25 bg-emerald-500/8'
                    : 'border-white/6 bg-white/[0.02]'
                }`}
              >
                <span
                  className={`h-1.5 w-1.5 rounded-full shrink-0 ${enabled ? 'bg-emerald-400 shadow-[0_0_6px_rgba(52,211,153,0.7)]' : 'bg-slate-700'}`}
                />
                <span className="font-mono text-xs text-slate-300 flex-1 truncate">{name}</span>
                <span
                  className={`text-[10px] font-semibold uppercase tracking-widest ${enabled ? 'text-emerald-400' : 'text-slate-700'}`}
                >
                  {enabled ? 'on' : 'off'}
                </span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </GlassCard>
  )
}

/* ── Stack ────────────────────────────────────────────────────── */
const STACK = [
  {
    category: 'Backend',
    color: 'indigo',
    tags: ['.NET 10', 'FastEndpoints', 'EF Core', 'Aspire', 'OpenIddict'],
  },
  {
    category: 'Frontend',
    color: 'violet',
    tags: ['React 19', 'TanStack Router', 'TanStack Query', 'Tailwind v4'],
  },
  {
    category: 'API layer',
    color: 'cyan',
    tags: ['OpenAPI', 'apx-gen', 'Auto-generated client', 'TypeScript'],
  },
  {
    category: 'Deployment',
    color: 'emerald',
    tags: ['SPA / SWA', 'Aspire', 'Docker', 'GitHub Actions'],
  },
] as const

type StackColor = (typeof STACK)[number]['color']

const colorMap: Record<StackColor, { label: string; pill: string; dot: string }> = {
  indigo: {
    label: 'text-indigo-400',
    pill: 'border-indigo-500/20 bg-indigo-500/8 text-indigo-300',
    dot: 'bg-indigo-400',
  },
  violet: {
    label: 'text-violet-400',
    pill: 'border-violet-500/20 bg-violet-500/8 text-violet-300',
    dot: 'bg-violet-400',
  },
  cyan: {
    label: 'text-cyan-400',
    pill: 'border-cyan-500/20 bg-cyan-500/8 text-cyan-300',
    dot: 'bg-cyan-400',
  },
  emerald: {
    label: 'text-emerald-400',
    pill: 'border-emerald-500/20 bg-emerald-500/8 text-emerald-300',
    dot: 'bg-emerald-400',
  },
}

function StackSection() {
  return (
    <section className="space-y-4">
      <h2 className="text-[10px] font-bold uppercase tracking-[0.2em] text-slate-600">Stack</h2>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        {STACK.map(({ category, color, tags }) => {
          const c = colorMap[color]
          return (
            <div
              key={category}
              className="rounded-xl border border-white/6 bg-white/[0.018] p-4 space-y-3 hover:border-white/12 transition-colors"
            >
              <div className="flex items-center gap-1.5">
                <span className={`h-1.5 w-1.5 rounded-full ${c.dot}`} />
                <span className={`text-[10px] font-semibold uppercase tracking-[0.15em] ${c.label}`}>
                  {category}
                </span>
              </div>
              <div className="flex flex-wrap gap-1.5">
                {tags.map((tag) => (
                  <span
                    key={tag}
                    className={`rounded-full border px-2 py-0.5 text-[10px] font-medium ${c.pill}`}
                  >
                    {tag}
                  </span>
                ))}
              </div>
            </div>
          )
        })}
      </div>
    </section>
  )
}
