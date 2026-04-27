# WebProject.Web

React 19 SPA — the frontend for this template. Built with TanStack Router, TanStack Query, and Tailwind v4. Served as static files; no Node server required.

---

## Table of contents

1. [Local development](#local-development)
2. [Aspire + Vite integration](#aspire--vite-integration)
3. [Rendering modes](#rendering-modes)
4. [API client](#api-client)
5. [Folder structure](#folder-structure)
6. [Scripts](#scripts)

---

## Local development

### With Aspire (recommended)

Start the full stack from the solution root:

```bash
dotnet run --project WebProject.AppHost
```

Aspire starts the API, database, and Vite dev server together. `VITE_API_BASE_URL` is injected automatically — no `.env.local` needed.

### Without Aspire (frontend only)

Copy `.env.example` to `.env.local` and point it at a running API:

```bash
cp .env.example .env.local
# Edit VITE_API_BASE_URL=http://localhost:5000
npm install
npm run dev
```

The app runs at `http://localhost:3000` (port set in `vite.config.ts`).

---

## Aspire + Vite integration

`WebProject.AppHost` registers the frontend via `AddViteApp`:

```csharp
var web = builder.AddViteApp("web", "../WebProject.Web")
    .WithEndpoint("http", e => e.Port = 5173)
    .WithEnvironment("VITE_API_BASE_URL", api.GetEndpoint("https"))
    .WithReference(api);
```

This does three things:

- Runs `npm run dev` inside `WebProject.Web` as an Aspire resource
- Injects `VITE_API_BASE_URL` with the API's HTTPS endpoint at startup
- Shows the frontend in the Aspire dashboard alongside the API and database

`VITE_API_BASE_URL` is consumed by the generated API client (`src/shared/clients/MyApiClient.ts`) as the base URL for all requests. It is the only environment variable the frontend needs.

---

## Rendering modes

This template ships in **SPA mode** — the default and recommended choice for authenticated dashboards, internal tools, and any app where SEO is not a concern.

### SPA mode (default)

`vite.config.ts` has `spa: { enabled: true }` inside `tanstackStart(...)`:

```ts
tanstackStart({ spa: { enabled: true } })
```

Output is a fully static bundle deployable to Azure Static Web Apps, S3, Vercel, or any CDN. No Node server required. Server functions and SSR APIs are unavailable in this mode — don't use `createServerFn` or `server:` route handlers.

### SSR (server-side rendering)

Remove `spa: { enabled: true }` from `vite.config.ts` to enable SSR. Individual routes can opt out of SSR with `ssr: false`.

**SSR changes the hosting story.** You need a running Node process, which means:
- Azure Static Web Apps is no longer viable
- Use Azure Container Apps, App Service, or Docker instead

Add these packages when switching to SSR (not needed in SPA mode):

```bash
npm install @tanstack/react-start @tanstack/react-router-ssr-query
```

### Data-only SSR (per route)

Set `ssr: 'data-only'` on a route to run its loader server-side while rendering the component client-side. Useful when you only need server-side data fetching on specific routes, without full HTML SSR.

### SSG

TanStack Start does not have first-class SSG support yet. For static site generation consider alternatives such as Astro or a pre-rendering step with a tool like `vite-ssg`.

---

## API client

The API client (`src/shared/clients/MyApiClient.ts`) is **auto-generated** from the backend's OpenAPI spec. Do not edit it manually — changes will be overwritten.

### Regenerate after backend changes

1. Build the API to refresh the OpenAPI spec:

   ```bash
   dotnet build ../WebProject.Api
   ```

2. Regenerate the client:

   ```bash
   npx apx-gen
   ```

The generator reads `apx-rest-config.json` and writes to `src/shared/clients/`.

### Usage pattern

Always use the client via `useQuery` / `useMutation` — never call it directly outside a query function:

```tsx
import { useQuery } from '@tanstack/react-query'
import { MyApiClient } from '@/shared/clients/MyApiClient'

const client = new MyApiClient()

const { data, isLoading } = useQuery({
  queryKey: ['resource', id],
  queryFn: async () => {
    const [result] = await client.getResource({ id })
    if (!result) throw new Error('Failed to load')
    return result
  },
})
```

---

## Folder structure

```
src/
  routes/                  # Pages — one file per route (TanStack Router file-based routing)
  │  __root.tsx            # Document shell: <html>, QueryClientProvider, devtools
  │  index.tsx             # Landing page
  │  demo/
  │     feature-flags.tsx  # Feature flags reference (real backend integration)
  │
  shared/                  # Shared, reusable code
  │  clients/              # AUTO-GENERATED — do not edit
  │  hooks/                # Reusable React hooks (e.g. useFeatureFlags)
  │  lib/                  # Pure utilities (e.g. cn() for class merging)
  │
  styles.css               # Global styles + Tailwind import
  router.tsx               # Router factory
```

Feature-specific code that grows beyond a single file belongs in `src/modules/[feature]/` — keep components, hooks, and types co-located by feature rather than by type.

---

## Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start Vite dev server on port 3000 |
| `npm run build` | Generate route tree + production build |
| `npm run preview` | Preview the production build locally |
| `npm run test` | Run Vitest tests |
| `npm run lint` | ESLint |
| `npm run check` | Prettier + ESLint (auto-fix) |
