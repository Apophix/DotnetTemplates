# GitHub Copilot Instructions

Full-stack web app: .NET 10 + FastEndpoints + EF Core + Aspire (backend), React 19 + TypeScript + TanStack + Tailwind v4 (frontend, SPA-only).

Detailed rules by file type are in `.github/instructions/` — this file covers workflow and cross-cutting concerns only.

## Workflow Rules
- **Commits**: Auto-commit is OK when working in a dedicated branch or autonomously; otherwise wait for explicit user instruction
- **Pause after backend API edits** — Aspire requires a manual restart; prompt the user before continuing to frontend work
- **One realm at a time** — complete backend changes before switching to frontend (unless told otherwise)
- **Prefer backend-first** when the task spans both realms
- **Windows/PowerShell** — always use PowerShell-compatible commands

## API Integration Flow
1. Create/modify FastEndpoint in `[Context].Application/Endpoints/`
2. Build the API project (`dotnet build`) so the OpenAPI spec updates
3. Run `npx apx-gen` in `[Project].Web` to regenerate the API client
4. Use `useApiClient()` + TanStack Query in the frontend component

## Environment Variables
- Frontend: `import.meta.env.VITE_*`
- Backend: `IConfiguration` via DI
- Never hardcode URLs or secrets

## General Code Principles
- Keep it simple; follow existing patterns; don't create abstractions prematurely
- Don't add dependencies without justification
- Prefer working code over perfect architecture