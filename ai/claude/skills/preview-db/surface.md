# surface — referencia de preview-db

## Cómo funciona (por qué esto da acceso)

El servicio Cloud Run `preview-rr` (proyecto `desarrolo-productos`, región `us-central1`) es un stack **Supabase self-hosted** multi-contenedor. Cada PR vivo es un **tag de tráfico** `pr-<N>` sobre ese servicio, con URL `https://pr-<N>---preview-rr-<hash>-uc.a.run.app` y su propia BD `pr_<N>` (efímera, clonada de `template_main`, dropeada al cerrar el PR).

Las credenciales **no** están en Secret Manager: viven como **env vars en texto plano** en la config de cada revisión. `preview_db.py` las lee con `gcloud run revisions describe` (permiso que la cuenta `cmoreno@dcanje.com` sí tiene) y usa el `SUPABASE_SERVICE_ROLE_KEY` contra la API REST del preview. El `service_role` **bypassa RLS** → acceso total a los datos.

## Resolver issue → PR

El motor trabaja con **números de PR**. Si te dan un issue (`RYR-131`):
1. Linear → `get_issue` → mirá `attachments` → el PR de `github.com/ivaldovinos-app/apprecio-pulse`.
2. Usá ese número con el motor.

## Filtros PostgREST (querystring)

| Operador | Ejemplo | Significa |
|---|---|---|
| `eq` / `neq` | `flag_key=eq.occ_automation_enabled` | igual / distinto |
| `gt` `gte` `lt` `lte` | `created_at=gte.2026-06-01` | comparación |
| `like` / `ilike` | `name=ilike.*haceb*` | patrón (i = case-insensitive) |
| `in` | `id=in.(1,2,3)` | pertenece |
| `is` | `deleted_at=is.null` | null / true / false |
| `order` | `order=created_at.desc` | orden |
| `limit` / `offset` | `limit=10&offset=20` | paginado |
| `select` | `select=id,name,tenant:tenants(name)` | columnas + embed de FK |

Combinaciones con `&`. Para `count`, el total viene en el header `Content-Range: 0-0/<N>`.

## Superficie completa del preview (referencia — la mayoría FUERA de scope)

Con el `service_role` el preview expone mucho más que datos. Esta skill **solo** cubre la capa de datos (REST tablas). Lo demás queda documentado por si algún día se amplía **deliberadamente**:

| Capa | Endpoint | En esta skill |
|---|---|---|
| Datos | `/rest/v1/<tabla>` (211 tablas/vistas) | ✅ **incluido** |
| RPC / funciones | `/rest/v1/rpc/<fn>` (~200 funciones de negocio) | ❌ fuera de scope |
| Auth admin | `/auth/v1/admin/*` (crear/borrar usuarios) | ❌ fuera de scope |
| Storage | `/storage/v1/*` (buckets/archivos) | ❌ fuera de scope |
| Config/secrets | env vars de la revisión (integraciones de terceros) | ❌ fuera de scope |

Ampliar la skill a esas capas es god-mode real: hacerlo solo con un caso de uso concreto y las mismas guardas (previews-only, confirmación de write, sin volcar credenciales).

## Límites

- **No** SQL arbitrario (JOINs ad-hoc, DDL, `EXPLAIN`, `pg_catalog`, transacciones): solo operaciones REST.
- Solo el schema **`public`** (lo que expone `PGRST_DB_SCHEMAS`).
- Solo **previews vivos** (con label `deploy:preview`); mueren al cerrar el PR.
- **Frágil:** depende de que el `service_role` siga en texto plano en la config. Si lo mueven a Secret Manager, esta vía se corta (Secret Manager está denegado para la cuenta).

## Acceso pleno (fuera de esta skill)

Para SQL arbitrario / psql sobre cualquier preview, la vía correcta es pedir a Ignacio el rol `roles/cloudsql.client` para `cmoreno@dcanje.com` sobre `desarrolo-productos` → habilita `cloud-sql-proxy` (túnel a la instancia `desarrolo-productos:us-central1:ryr-preview`). Eso es acceso de fondo, no un atajo; esta skill es el puente mientras tanto.
