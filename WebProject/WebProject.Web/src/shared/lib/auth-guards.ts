import { redirect } from '@tanstack/react-router'
import { getAuthSnapshot, waitForAuthInit } from '@/shared/auth/AuthContext'

type BeforeLoadArgs = { location: { href: string } }

/**
 * TanStack Router `beforeLoad` guard — requires authentication.
 * Waits for the initial silent-refresh attempt before deciding,
 * so users with a valid refresh token are not bounced on first load.
 *
 * Usage:
 * ```ts
 * export const Route = createFileRoute('/protected')({
 *   beforeLoad: requireAuth,
 *   component: MyPage,
 * })
 * ```
 */
export async function requireAuth({ location }: BeforeLoadArgs) {
  await waitForAuthInit()
  if (!getAuthSnapshot().isAuthenticated) {
    sessionStorage.setItem('auth_return_url', location.href)
    throw redirect({ to: '/' })
  }
}

/**
 * TanStack Router `beforeLoad` guard — requires a specific role.
 * Returns a `beforeLoad` function; wrap it at the route definition.
 *
 * Usage:
 * ```ts
 * export const Route = createFileRoute('/admin')({
 *   beforeLoad: requireRole('Admin'),
 *   component: AdminPage,
 * })
 * ```
 */
export function requireRole(role: string) {
  return async function beforeLoad({ location }: BeforeLoadArgs) {
    await waitForAuthInit()
    const { isAuthenticated, user } = getAuthSnapshot()
    if (!isAuthenticated) {
      sessionStorage.setItem('auth_return_url', location.href)
      throw redirect({ to: '/' })
    }
    if (!user?.roles.includes(role)) {
      throw redirect({ to: '/', search: { forbidden: '1' } })
    }
  }
}
