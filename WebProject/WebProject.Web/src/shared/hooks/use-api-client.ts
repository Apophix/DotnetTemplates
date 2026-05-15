import { useMemo } from 'react'
import { MyApiClient } from '@/shared/clients/MyApiClient'
import { useAuth } from '@/shared/auth/AuthContext'

/**
 * Returns an API client that automatically injects `Authorization: Bearer <token>`
 * on every request. Use for endpoints that require authentication.
 */
export function useApiClient(): MyApiClient {
  const { getAccessToken } = useAuth()
  return useMemo(() => {
    const client = new MyApiClient()
    client.useBearerTokenProvider(getAccessToken)
    client.useBearerTokenByDefault(true)
    return client
  }, [getAccessToken])
}

/**
 * Returns an API client with no auth headers.
 * Use for public endpoints that never require a token.
 */
export function usePublicApiClient(): MyApiClient {
  return useMemo(() => new MyApiClient(), [])
}
