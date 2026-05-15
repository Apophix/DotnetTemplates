export type AuthUser = {
  sub: string
  name?: string
  email?: string
  roles: string[]
}

export type AuthTokens = {
  accessToken: string
  /** Unix epoch seconds */
  expiresAt: number
}
