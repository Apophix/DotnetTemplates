import { createFileRoute, Link } from '@tanstack/react-router'
import { requireAuth } from '@/shared/lib/auth-guards'
import { useAuth } from '@/shared/auth/AuthContext'

export const Route = createFileRoute('/demo/protected')({
  beforeLoad: requireAuth,
  component: ProtectedPage,
})

function ProtectedPage() {
  const { user, clearTokens } = useAuth()

  return (
    <main className="mx-auto max-w-2xl px-4 py-10 space-y-6">
      <div>
        <Link
          to="/"
          className="text-xs text-slate-500 hover:text-slate-300 transition-colors"
        >
          ← Back
        </Link>
        <h1 className="text-2xl font-bold mt-3">Protected Route</h1>
        <p className="mt-1 text-muted-foreground text-sm">
          You reached this page because you are authenticated.
        </p>
      </div>

      <div className="rounded-xl border bg-card p-5 shadow-sm space-y-4">
        <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">
          Current User
        </h2>
        <dl className="divide-y divide-slate-800 rounded-lg border border-slate-800 overflow-hidden text-sm">
          <Row label="Subject" value={user?.sub ?? '—'} />
          <Row label="Email" value={user?.email ?? '—'} />
          <Row label="Name" value={user?.name ?? '—'} />
          <Row label="Roles" value={user?.roles.join(', ') ?? '—'} />
        </dl>
      </div>

      <div className="rounded-xl border bg-card p-5 shadow-sm space-y-3">
        <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">
          RBAC Demo
        </h2>
        <RbacDemo roles={user?.roles ?? []} />
      </div>

      <button
        onClick={clearTokens}
        className="rounded bg-slate-700 px-4 py-2 text-sm text-slate-200 hover:bg-slate-600 transition-colors"
      >
        Logout
      </button>
    </main>
  )
}

function RbacDemo({ roles }: { roles: string[] }) {
  const hasAdmin = roles.includes('Admin')
  const hasUser = roles.includes('User')

  return (
    <ul className="space-y-2 text-sm">
      <li className="flex items-center gap-2">
        <RoleDot on={hasUser} />
        <span>User role — read access to standard features</span>
      </li>
      <li className="flex items-center gap-2">
        <RoleDot on={hasAdmin} />
        <span>Admin role — access to admin features</span>
      </li>
    </ul>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex gap-4 px-4 py-2.5 bg-slate-900">
      <dt className="w-20 shrink-0 text-slate-500">{label}</dt>
      <dd className="font-mono text-slate-300 break-all">{value}</dd>
    </div>
  )
}

function RoleDot({ on }: { on: boolean }) {
  return (
    <span
      className={`inline-block h-2.5 w-2.5 rounded-full shrink-0 ${on ? 'bg-emerald-500' : 'bg-slate-600'}`}
    />
  )
}
