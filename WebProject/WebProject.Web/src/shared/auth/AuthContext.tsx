import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { getTokenExpiry, parseUserFromToken } from './token-utils'
import type { AuthUser } from './types'

type AuthContextValue = {
  user: AuthUser | null
  isAuthenticated: boolean
  /** True until the first silent-refresh attempt has completed. */
  isLoading: boolean
  /**
   * Returns the current access token, triggering a silent refresh if none is
   * held. Stable reference — safe as a `useBearerTokenProvider` argument.
   */
  getAccessToken: () => Promise<string>
  /** Store new tokens and update the decoded user. */
  setTokens: (accessToken: string, refreshToken?: string) => void
  /** Clear all tokens and user state (logout). */
  clearTokens: () => void
  /** Attempt a silent refresh using the stored refresh token / HttpOnly cookie. */
  refreshAsync: () => Promise<boolean>
}

// ─── Module-level snapshot (for use outside React, e.g. route beforeLoad) ─────

type AuthSnapshot = { isAuthenticated: boolean; user: AuthUser | null; isLoading: boolean }

let _authSnapshot: AuthSnapshot = { isAuthenticated: false, user: null, isLoading: true }

/** Read the latest auth state outside of React (e.g. in route `beforeLoad`). */
export function getAuthSnapshot(): AuthSnapshot {
  return _authSnapshot
}

let _initResolve: (() => void) | null = null
const _initPromise = new Promise<void>((resolve) => {
  _initResolve = resolve
})

/**
 * Resolves after the first silent-refresh attempt finishes (success or failure).
 * Use this in `beforeLoad` guards to avoid redirecting during app initialisation.
 */
export function waitForAuthInit(): Promise<void> {
  return _initPromise
}

// ─── Context ──────────────────────────────────────────────────────────────────

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const accessTokenRef = useRef<string | null>(null)
  const refreshTokenRef = useRef<string | null>(null)
  const refreshTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const refreshInFlightRef = useRef<Promise<boolean> | null>(null)
  const refreshAsyncRef = useRef<() => Promise<boolean>>(async () => false)

  const [user, setUser] = useState<AuthUser | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  const setTokens = useCallback((accessToken: string, refreshToken?: string) => {
    const parsedUser = parseUserFromToken(accessToken)
    accessTokenRef.current = accessToken
    if (refreshToken) refreshTokenRef.current = refreshToken
    setUser(parsedUser)
    _authSnapshot = { isAuthenticated: true, user: parsedUser, isLoading: false }

    const exp = getTokenExpiry(accessToken)
    if (exp > 0) {
      if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current)
      const delay = Math.max(0, exp * 1000 - Date.now() - 60_000)
      refreshTimerRef.current = setTimeout(() => void refreshAsyncRef.current(), delay)
    }
  }, []) // stable: only writes to refs and calls stable setUser

  const clearTokens = useCallback(() => {
    accessTokenRef.current = null
    refreshTokenRef.current = null
    if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current)
    setUser(null)
    _authSnapshot = { isAuthenticated: false, user: null, isLoading: false }
  }, []) // stable

  const refreshAsync = useCallback(async (): Promise<boolean> => {
    if (refreshInFlightRef.current) return refreshInFlightRef.current

    const doRefresh = async (): Promise<boolean> => {
      const baseUrl = import.meta.env.VITE_API_BASE_URL as string
      const body = new URLSearchParams({ grant_type: 'refresh_token', client_id: 'web-client' })
      if (refreshTokenRef.current) body.set('refresh_token', refreshTokenRef.current)
      try {
        const res = await fetch(`${baseUrl}/connect/token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: body.toString(),
          credentials: 'include', // sends HttpOnly refresh-token cookie if present
        })
        if (!res.ok) { clearTokens(); return false }
        const data = await res.json() as { access_token?: string; refresh_token?: string }
        if (!data.access_token) { clearTokens(); return false }
        setTokens(data.access_token, data.refresh_token)
        return true
      } catch {
        return false
      } finally {
        refreshInFlightRef.current = null
      }
    }

    refreshInFlightRef.current = doRefresh()
    return refreshInFlightRef.current
  }, [clearTokens, setTokens]) // both stable → refreshAsync is also stable

  // Keep the ref in sync so the expiry timer always calls the latest version.
  useEffect(() => {
    refreshAsyncRef.current = refreshAsync
  }, [refreshAsync])

  // Attempt silent restore on app start; signal init completion regardless of outcome.
  useEffect(() => {
    refreshAsync().finally(() => {
      setIsLoading(false)
      _authSnapshot = { ..._authSnapshot, isLoading: false }
      _initResolve?.()
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []) // intentionally empty — run once on mount

  const getAccessToken = useCallback(async (): Promise<string> => {
    if (!accessTokenRef.current) {
      await refreshAsync()
    }
    return accessTokenRef.current ?? ''
  }, [refreshAsync]) // refreshAsync is stable → getAccessToken is stable

  return (
    <AuthContext
      value={{ user, isAuthenticated: user !== null, isLoading, getAccessToken, setTokens, clearTokens, refreshAsync }}
    >
      {children}
    </AuthContext>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider')
  return ctx
}
