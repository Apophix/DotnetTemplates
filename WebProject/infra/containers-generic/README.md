# containers-generic — Docker Compose (local dev)

A self-contained local development environment using Docker Compose. No Azure account, no Aspire
runtime, no `dotnet watch` — just `docker compose up`.

> **Recommended local dev path**: The [Aspire AppHost](../../WebProject.AppHost/) provides richer
> tooling (service discovery, dashboard, automatic port wiring). Use this Compose file when you
> prefer a docker-only workflow or when Aspire tooling is unavailable.

## Services

| Service | Image / Source | Host port |
|---------|----------------|-----------|
| `db` | `mcr.microsoft.com/mssql/server:2022-latest` | 1433 |
| `api` | Built from repo root (`WebProject.Api/Dockerfile`) | 8080 |
| `web` | Built from `WebProject.Web/Dockerfile` (Caddy serving Vite build) | 5173 → 80 |

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or any Docker Engine + Compose v2)
- No Azure account required

## Quick start

**1. Create a `.env` file** in this directory:

```env
MSSQL_SA_PASSWORD=YourStr0ng!Passw0rd
```

The password must satisfy SQL Server complexity rules (min 8 chars, mix of upper, lower, digit, symbol).

**2. Start all services:**

```bash
docker compose --file infra/containers-generic/docker-compose.yml up --build
```

Or from this directory:

```bash
docker compose up --build
```

**3. Apply EF Core migrations** (once the API is healthy):

```bash
dotnet run --project WebProject.MigrationService
```

Or with the connection string passed directly:

```bash
dotnet run --project WebProject.MigrationService \
  -- --connectionString "Server=tcp:localhost,1433;Initial Catalog=webproject-dev;User ID=sa;Password=YourStr0ng!Passw0rd;Encrypt=True;TrustServerCertificate=True;"
```

**4. Open the app** at [http://localhost:5173](http://localhost:5173)

API health: [http://localhost:8080/alive](http://localhost:8080/alive)

## URLs

| Endpoint | URL |
|----------|-----|
| React SPA (Vite HMR) | http://localhost:5173 |
| API | http://localhost:8080 |
| SQL Server | localhost,1433 (SA login) |

## How `VITE_API_BASE_URL` works

`VITE_API_BASE_URL` is passed as a Docker build arg and baked into the JavaScript bundle at
build time by Vite. The browser on your host calls `localhost:8080` directly — Docker maps
port 8080 on the host to the API container.

To change the API URL, rebuild the `web` image:

```bash
docker compose up --build web
```

## Code changes

Because `VITE_API_BASE_URL` is compiled into the image, code changes to the frontend require a
rebuild:

```bash
docker compose up --build web
```

For iterative frontend development, use the [Aspire AppHost](../../WebProject.AppHost/) instead,
which runs the Vite dev server with HMR.

## Stopping and cleaning up

```bash
# Stop containers (data volume preserved)
docker compose down

# Stop and remove the SQL data volume (full reset)
docker compose down --volumes
```

## Differences from Aspire AppHost

| | Aspire AppHost | Docker Compose |
|---|---|---|
| Service discovery | Automatic | Manual env vars |
| Dashboard | Built-in at port 18888 | None |
| Hot reload (API) | `dotnet watch` | Requires rebuild |
| Hot reload (web) | Vite HMR (automatic) | Requires rebuild |
| Azure emulators | Optional | Not included |
| Migrations | Automatic via MigrationService | Manual (`dotnet run`) |

## Notes

- SQL data is persisted in the `sql-data` named volume between restarts.
- The frontend image is built with Caddy serving the Vite production build (SPA `try_files` fallback included). For iterative
  frontend work, use Aspire AppHost instead (Vite dev server with HMR).
- The API Dockerfile copies the entire repo context so all referenced projects
  (`Sample.Application`, `Sample.Domain`, `Sample.Infrastructure`, etc.) are available
  at build time.
- To rebuild after code changes: `docker compose up --build`
