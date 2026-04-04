import { useQuery } from '@tanstack/react-query'
import { MyApiClient } from '@/lib/clients/MyApiClient'

const client = new MyApiClient()

export function useFeatureFlags(): Record<string, boolean> {
  const { data } = useQuery({
    queryKey: ['feature-flags'],
    queryFn: async () => {
      const [result] = await client.getFeatureFlags()
      if (!result) throw new Error('Failed to load feature flags')
      return result
    },
    staleTime: 5 * 60 * 1000,
  })
  // flags is a Map<string, boolean> from the generated client — convert to plain Record
  return data ? Object.fromEntries(data.flags) : {}
}

export function useFeatureFlag(name: string): boolean {
  return useFeatureFlags()[name] ?? false
}
