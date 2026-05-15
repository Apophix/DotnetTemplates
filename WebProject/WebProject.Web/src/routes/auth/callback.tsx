import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import { useAuth } from '@/shared/auth/AuthContext'

export const Route = createFileRoute('/auth/callback')({
  validateSearch: (search: Record<string, unknown>) => ({
    code: typeof search['code'] === 'string' ? search['code'] : undefined,
    state: typeof search['state'] === 'string' ? search['state'] : undefined,
    error: typeof search['error'] === 'string' ? search['error'] : undefined,
    error_description:
      typeof search['error_description'] === 'string'
        ? search['error_description']
        : undefined,
  }),
  component: CallbackPage,
})

function CallbackPage() {
  const { code, state, error, error_description } = Route.useSearch()
  const { setTokens } = useAuth()
  const navigate = useNavigate()
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  useEffect(() => {
    if (error) {
      setErrorMsg(error_description ?? error)
      return
    }
    if (!code) {
      setErrorMsg('Missing authorization code.')
      return
    }

    const verifier = sessionStorage.getItem('pkce_verifier')
    const storedState = sessionStorage.getItem('pkce_state')
    const returnUrl = sessionStorage.getItem('auth_return_url') ?? '/'
    sessionStorage.removeItem('pkce_verifier')
    sessionStorage.removeItem('pkce_state')
    sessionStorage.removeItem('auth_return_url')

    if (state && state !== storedState) {
      setErrorMsg('State mismatch — request may have been tampered with.')
      return
    }

    const baseUrl = import.meta.env.VITE_API_BASE_URL as string
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: 'web-client',
      code,
      redirect_uri: `${window.location.origin}/auth/callback`,
      code_verifier: verifier ?? '',
    })

    fetch(`${baseUrl}/connect/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
      credentials: 'include',
    })
      .then((res) => res.json())
      .then((data: { access_token?: string; refresh_token?: string; error?: string }) => {
        if (data.error || !data.access_token) {
          setErrorMsg(data.error ?? 'Token exchange failed.')
          return
        }
        setTokens(data.access_token, data.refresh_token)
        void navigate({ to: returnUrl as '/', replace: true })
      })
      .catch(() => setErrorMsg('Network error during token exchange.'))
  }, []) // intentionally empty — runs once on mount

  if (errorMsg) {
    return (
      <main className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center">
        <div className="text-center space-y-4 max-w-sm px-6">
          <p className="text-red-400 text-sm">Sign-in failed: {errorMsg}</p>
          <a href="/" className="text-slate-400 underline text-sm block">
            Return home
          </a>
        </div>
      </main>
    )
  }

  return (
    <main className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center">
      <p className="text-slate-400 text-sm">Completing sign-in…</p>
    </main>
  )
}
