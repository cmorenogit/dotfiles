# Rename Session

Genera un nombre descriptivo para la sesión actual basado en el contexto de trabajo.
Presenta 3 opciones para que el usuario elija.

**Argumento opcional:** $ARGUMENTS (proyecto, ticket o contexto adicional)

## Formato

```
[proyecto] PM-XXXX descripcion-de-lo-trabajado
```

Donde:
- `[proyecto]` = rr | fuerza | engagement | smart-loyalty | apprecio | otros
- `PM-XXXX` = incluir SIEMPRE que haya un ticket JIRA asociado (importante para búsqueda rápida)
- `descripcion` = 4-8 palabras, descriptiva de lo que se HIZO, no solo el tema

## Algoritmo

### PASO 1: Analizar contexto de la sesión

Revisar toda la conversación para extraer:

1. **Proyecto:** Detectar del directorio de trabajo, archivos editados, o mención explícita

   | Signal | Proyecto |
   |--------|----------|
   | `back-pulse`, `app-rr`, Supabase/Deno, edge functions | `rr` |
   | `fuerza`, servicios dcanje, Express/MongoDB, PHP/Laravel | `fuerza` |
   | `engagement`, Angular 17 SSR, apprecio-play, copilot-service | `engagement` |
   | `smart-loyalty`, GraphQL/Angular 10 | `smart-loyalty` |
   | `docs-projects/_work/apprecio`, estado-semana, weekly | `apprecio` |
   | Ninguno de los anteriores | `otros` |

2. **Ticket JIRA:** Buscar menciones de `PM-XXXX` en mensajes, archivos leídos, commits, PRs. Incluir en el nombre si existe.

3. **Qué se hizo:** Identificar la acción principal de la sesión:
   - ¿Se resolvió un bug? ¿Se implementó una feature? ¿Se hizo investigación?
   - ¿Se creó un PR? ¿Se desplegó? ¿Se configuró algo?
   - ¿Se procesó una reunión? ¿Se planificó?

### PASO 2: Generar 3 opciones

Crear 3 nombres con diferentes niveles de detalle:

**Reglas para buenos nombres:**
- Describir QUÉ SE HIZO, no solo el tema
- Usar verbos en pasado o sustantivos de acción
- 4-8 palabras de descripción (no contar proyecto ni ticket)
- Minúsculas, sin acentos
- Términos técnicos concretos (no genéricos)
- PM-XXXX siempre que haya ticket asociado

**Buenos nombres:**
```
[fuerza] PM-2233 fix compresion imagenes registro fotografico
[rr] challenges fase 1 state machine e inscripcion
[engagement] preparar PRs jenkinsfile multi-country deploy
[apprecio] ingest planning w10 desafios y encuestas
[otros] auditoria limpieza config claude code
```

**Malos nombres:**
```
[fuerza] fix bug                      ← muy genérico
[rr] working on stuff                 ← no dice nada
[fuerza] PM-2233 registro             ← muy corto, no dice qué se hizo
```

### PASO 3: Presentar opciones

Mostrar las 3 opciones numeradas:

```
Opciones para renombrar sesión:

1. [proyecto] PM-XXXX descripcion-detallada
2. [proyecto] PM-XXXX descripcion-alternativa
3. [proyecto] descripcion-sin-ticket (si aplica)

¿Cuál? (1/2/3)
```

- Si hay ticket JIRA, las 3 opciones deben incluirlo
- Si no hay ticket, ninguna lo incluye
- Las opciones deben variar en enfoque (ej: una por la acción, otra por el resultado, otra por el contexto)

### PASO 4: Aplicar

Según la elección del usuario, ejecutar el rename.

Si `$ARGUMENTS` contiene un nombre directo (ej: `/rename-session fix login fuerza`), usarlo como hint para generar las 3 opciones.

## Ejemplos

**Sesión de bug fix con ticket:**
```
1. [fuerza] PM-2233 fix compresion imagenes blob fallback
2. [fuerza] PM-2233 registro fotografico compresion y deploy
3. [fuerza] PM-2233 resolver solo camara web restriccion fotos
```

**Sesión de feature sin ticket:**
```
1. [rr] challenges fase 1 validaciones e inscripcion automatica
2. [rr] implementar state machine challenges con tests
3. [rr] challenges backoffice crud y edge functions
```

**Sesión de reunión/docs:**
```
1. [apprecio] ingest planning w10 desafios puntos engagement
2. [apprecio] procesar reunion lunes prioridades semana
3. [apprecio] planning w10 foco desafios y encuestas abiertas
```

**Sesión de config/tooling:**
```
1. [otros] auditoria config claude code eliminar duplicados
2. [otros] limpieza skills commands y symlinks claude
3. [otros] estandarizar agents.md y limpiar redundancia
```

## Notas

- Si la sesión acaba de empezar y no hay contexto, preguntar qué se va a trabajar
- PM-XXXX es CLAVE para búsqueda rápida en historial de sesiones
- El nombre debe ser útil 2 semanas después — ¿podrías encontrar esta sesión buscando por ese nombre?
