import { useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useAuth } from '@/shared/auth/AuthContext'

const DEV_LOGIN_ENABLED =
  import.meta.env.DEV || import.meta.env.VITE_DEV_LOGIN_ENABLED === 'true'

const BASE_URL = import.meta.env.VITE_API_BASE_URL as string
const CLIENT_ID = 'web-client'

type DevAccount = {
  label: string
  username: string
  password: string
}

const DEV_ACCOUNTS: DevAccount[] = [
  { label: 'Login as User', username: 'user@localhost', password: 'DevPass1!' },
  { label: 'Login as Admin', username: 'admin@localhost', password: 'DevPass1!' },
]

export function DevLoginPanel() {
  if (!DEV_LOGIN_ENABLED) return null
  return <DevLoginPanelInner />
}

function DevLoginPanelInner() {
  const { user, isAuthenticated, setTokens, clearTokens } = useAuth()
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState<string | null>(null)

  async function handleLogin(account: DevAccount) {
    setError(null)
    setLoading(account.username)
    try {
      const body = new URLSearchParams({
        grant_type: 'password',
        client_id: CLIENT_ID,
        username: account.username,
        password: account.password,
        scope: 'openid profile email roles offline_access',
      })
      const res = await fetch(`${BASE_URL}/connect/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString(),
        credentials: 'include',
      })
      const data = await res.json() as {
        access_token?: string
        refresh_token?: string
        error?: string
        error_description?: string
      }
      if (!res.ok || !data.access_token) {
        setError(data.error_description ?? data.error ?? 'Login failed.')
        return
      }
      setTokens(data.access_token, data.refresh_token)
      void navigate({ to: '/' })
    } catch {
      setError('Network error.')
    } finally {
      setLoading(null)
    }
  }

  function handleLogout() {
    clearTokens()
  }

  return (
    <div className="fixed bottom-4 right-4 z-50 rounded-xl border border-slate-700 bg-slate-900 p-4 shadow-xl text-sm w-64 space-y-3">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
        Dev Login Panel
      </p>

      {isAuthenticated && user ? (
        <div className="space-y-2">
          <p className="text-slate-300 truncate">{user.email ?? user.sub}</p>
          <p className="text-xs text-slate-500">{user.roles.join(', ')}</p>
          <button
            onClick={handleLogout}
            className="w-full rounded bg-slate-700 px-3 py-1.5 text-slate-200 hover:bg-slate-600 transition-colors"
          >
            Logout
          </button>
        </div>
      ) : (
        <div className="space-y-2">
          {DEV_ACCOUNTS.map((account) => (
            <button
              key={account.username}
              onClick={() => void handleLogin(account)}
              disabled={loading !== null}
              className="w-full rounded bg-indigo-600 px-3 py-1.5 text-white hover:bg-indigo-500 disabled:opacity-50 transition-colors"
            >
              {loading === account.username ? 'Signing in…' : account.label}
            </button>
          ))}
          {error && <p className="text-xs text-red-400">{error}</p>}
        </div>
      )}
    </div>
  )
}
