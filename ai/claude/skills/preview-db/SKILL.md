---
name: preview-db
description: >
  Acceso de lectura/escritura a la BD de un preview de Beat (por PR o issue) vía la API REST del
  preview con el service_role — leer tablas, contar filas y, con confirmación, escribir filas o
  activar/desactivar feature flags. Solo previews (nunca producción). User-invoked: la llamás vos.
disable-model-invocation: true
---

# preview-db — datos de un preview de Beat

Accede a la BD de **el preview de un PR** de Beat (backoffice `apprecio-pulse`) por su **API REST** con el `service_role`. No pasa por Cloud SQL — usa lo que ya es legible en la config del Cloud Run del preview (`gcloud run …describe`). Solo **previews** (efímeros, aislados); **nunca producción**.

**Motor:** `preview_db.py` (stdlib, sin dependencias), en el base dir de esta skill. Requiere `gcloud` logueado.

## Guardas (siempre)

- **Solo previews.** El motor aborta si la URL no es `pr-N---preview-rr`. No apuntes a prod por ninguna vía.
- **Write con confirmación.** `patch`/`post`/`delete` hacen **DRY-RUN** salvo `--confirm`. Mostrá el cambio exacto (tabla · filtro · valor) y esperá el OK de César **antes** de `--confirm`.
- **Verificá el preview correcto.** El servicio `preview-rr` es compartido entre PRs; el motor imprime `tag → revisión` — confirmá que es el PR que querés antes de escribir.
- **Nunca imprimas el `service_role`.** El motor lo redacta; no lo vuelques crudo.
- **Fuera de scope:** RPC (`/rpc`), auth admin (`/auth/v1/admin`) y storage (`/storage/v1`). Existen en el preview pero esta skill **no** los expone. Si alguna vez hacen falta, se amplía deliberadamente con las mismas guardas (ver `surface.md`).

## Pasos

1. **Resolver el preview.**
   - Si te dan un **issue** (`RYR-131`), resolvé su PR primero: Linear → attachments → el PR de `apprecio-pulse`. Si te dan el **PR**, usalo directo.
   - `preview_db.py list` confirma que `pr-N` está vivo. Si no aparece → el preview no está deployado (le falta el label `deploy:preview`); decílo y parás.
2. **Read** (inspección, sin fricción): `tables` / `get` / `count`. Mostrá el resultado.
3. **Write** (gated):
   - Corré primero en **DRY-RUN** (sin `--confirm`) para mostrar exactamente qué cambiaría.
   - Mostrá a César tabla · filtro · valor nuevo y esperá su OK.
   - Ejecutá con `--confirm`.
   - **Verificá con un `get` posterior** que quedó como se esperaba — no des por hecho el `HTTP 200`.

## Comandos

```
preview_db.py list                                          # previews vivos (tag -> revisión)
preview_db.py <PR> tables [filtro]                          # schema del preview
preview_db.py <PR> get    <tabla> [querystring]             # leer filas
preview_db.py <PR> count  <tabla> [querystring]             # contar (Content-Range: .../N)
preview_db.py <PR> patch  <tabla> <filtro> <json> --confirm # update
preview_db.py <PR> post   <tabla> <json> --confirm          # insert
preview_db.py <PR> delete <tabla> <filtro> --confirm        # delete
```

Ejemplo (activar un flag para QA):
```
preview_db.py 666 get   feature_flag_defaults "flag_key=eq.occ_automation_enabled&select=flag_key,default_value"
preview_db.py 666 patch feature_flag_defaults "flag_key=eq.occ_automation_enabled" '{"default_value":true}'   # dry-run
preview_db.py 666 patch feature_flag_defaults "flag_key=eq.occ_automation_enabled" '{"default_value":true}' --confirm
```

## Referencia

Filtros PostgREST, resolución issue→PR, superficie completa y límites → `surface.md`.
