import type { AuthUser } from './types'

/** Decode the payload section of a JWT without verifying the signature. */
export function decodeJwtPayload(token: string): Record<string, unknown> {
  try {
    const payload = token.split('.')[1]
    const padded = payload.replace(/-/g, '+').replace(/_/g, '/')
    return JSON.parse(atob(padded)) as Record<string, unknown>
  } catch {
    return {}
  }
}

/** Extract a user object from an access token's claims. */
export function parseUserFromToken(accessToken: string): AuthUser {
  const p = decodeJwtPayload(accessToken)
  return {
    sub: typeof p['sub'] === 'string' ? p['sub'] : '',
    name: typeof p['name'] === 'string' ? p['name'] : undefined,
    email: typeof p['email'] === 'string' ? p['email'] : undefined,
    roles: parseRoles(p['role']),
  }
}

/** Returns the token expiry as a Unix epoch seconds timestamp (0 if missing). */
export function getTokenExpiry(accessToken: string): number {
  const p = decodeJwtPayload(accessToken)
  return typeof p['exp'] === 'number' ? p['exp'] : 0
}

function parseRoles(role: unknown): string[] {
  if (Array.isArray(role)) return role as string[]
  if (typeof role === 'string') return [role]
  return []
}
