import posthog from 'posthog-js'

const key = import.meta.env.VITE_POSTHOG_KEY as string | undefined
const host = (import.meta.env.VITE_POSTHOG_HOST as string | undefined) ?? 'https://us.i.posthog.com'

if (key) {
  posthog.init(key, {
    api_host: host,
    person_profiles: 'identified_only',
  })
}

export { posthog }
