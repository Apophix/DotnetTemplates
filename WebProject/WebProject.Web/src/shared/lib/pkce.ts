/** Generate a random PKCE code verifier (43–128 chars, URL-safe). */
export function generateCodeVerifier(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(64))
  return base64UrlEncode(bytes)
}

/** Derive the PKCE code challenge from a verifier (S256 method). */
export async function generateCodeChallenge(verifier: string): Promise<string> {
  const data = new TextEncoder().encode(verifier)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return base64UrlEncode(new Uint8Array(digest))
}

export type AuthorizationUrlParams = {
  baseUrl: string
  clientId: string
  redirectUri: string
  state: string
  codeChallenge: string
  scope?: string
}

/**
 * Build an `/connect/authorize` URL with PKCE parameters.
 * Stores the code verifier and state in sessionStorage for the callback.
 */
export function buildAuthorizationUrl({
  baseUrl,
  clientId,
  redirectUri,
  state,
  codeChallenge,
  scope = 'openid profile email roles offline_access',
}: AuthorizationUrlParams): string {
  const url = new URL('/connect/authorize', baseUrl)
  url.searchParams.set('response_type', 'code')
  url.searchParams.set('client_id', clientId)
  url.searchParams.set('redirect_uri', redirectUri)
  url.searchParams.set('state', state)
  url.searchParams.set('code_challenge', codeChallenge)
  url.searchParams.set('code_challenge_method', 'S256')
  url.searchParams.set('scope', scope)
  return url.toString()
}

/** Generate a random state value for CSRF protection. */
export function generateState(): string {
  return base64UrlEncode(crypto.getRandomValues(new Uint8Array(16)))
}

function base64UrlEncode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')
}
