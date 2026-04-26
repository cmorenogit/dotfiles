---
description: Revisar consolidado semanal de conocimiento — acciones pendientes, drill-down e investigación
---

# Consolidado Semanal — Revisión de Acciones

Comando para revisar el consolidado semanal de conocimiento, gestionar el estado de acciones y profundizar en contenidos.

## Argumentos

```
/consolidado              # Revisar acciones pendientes (modo interactivo)
/consolidado --status     # Vista rápida de todas las acciones
/consolidado --deep N     # Profundizar en la acción número N
```

## Fuente de Datos

- **Consolidado vivo:** `consolidado-semanal.md` en carpeta Consolidados
- **Carpeta Consolidados (Drive):** ID `19LdECi9R2Ny6g_IwhTLvnXcXN21CCAo1`
- **Carpeta Backlog (Drive):** ID `12_dxa67Tx4Z407PSRZ9y0VhlEPFRrB_0`
- **Resúmenes y transcripciones:** Links dentro del propio consolidado (Drive URLs)
- **Perfil profesional:** Engram topic `profile/cesar-moreno`

## Modo: Revisar (default)

### Algoritmo

1. **Descargar consolidado** de Drive:
   ```bash
   gws drive files list --params '{"q": "name=\"consolidado-semanal.md\" and \"19LdECi9R2Ny6g_IwhTLvnXcXN21CCAo1\" in parents and trashed=false", "fields": "files(id,name)"}'
   ```
   Luego descargar con el ID encontrado:
   ```bash
   gws drive files get --params '{"fileId": "ID_ENCONTRADO", "alt": "media"}'
   ```

2. **Parsear sección `## 🚀 Acciones`** — extraer todas las acciones con su estado actual

3. **Filtrar acciones que necesitan atención:** ⬜ (pendiente), 👁️ (revisada), 🎯 (adoptada no implementada)

4. **Si no hay acciones pendientes:** Mostrar "Todo revisado" + resumen de estados y terminar.

5. **Presentar cada acción pendiente** con contexto breve extraído de la sección `## 📋 Contenidos` del consolidado:

   ```markdown
   ## Acciones pendientes — WXX (N items)

   | # | Estado | Acción | Esfuerzo | Contenido origen |
   |---|--------|--------|----------|-----------------|
   | 1 | ⬜ | Configurar cooldown NPM | ⚡ 5 min | CodelyTV — Zeline hack |
   | 2 | 👁️ | GGA pre-commit hook | 📅 1-2h | Gentleman Programming |
   | 3 | 🎯 | Documentar workflow agentes | 🗓️ | Yesi Days |

   ¿Qué hacemos?
   ```

6. **César elige** mediante pregunta interactiva por cada acción (o en lote):
   - 👁️ **Revisada** — "La vi, después decido"
   - 🎯 **Adoptar** — "Quiero implementarla"
   - 📌 **Enviar a Backlog** — "Quiero pero hay bloqueador" (solo después de deep dive; pedir bloqueador y proyecto target)
   - ❌ **Descartar** — "No aplica" (pedir razón breve)
   - ✅ **Ya implementada** — "Ya está hecha" (pedir fecha + dónde)
   - **"Cuéntame más"** — Cambiar a modo `--deep` para esa acción

7. **Actualizar consolidado** con los nuevos estados siguiendo el formato de la guía:
   - ❌: `❌ ~~texto original~~ — razón`
   - ✅: `✅ ~~texto original~~ — fecha | dónde/cómo`
   - 🎯: `🎯 texto original`
   - 👁️: `👁️ texto original`
   - 📌: `📌 texto original — bloqueador. Brief: Backlog/nombre-archivo.md. Target: proyecto`

8. **Si hay items nuevos 📌:** Crear brief en `Backlog/` (Drive folder ID: `12_dxa67Tx4Z407PSRZ9y0VhlEPFRrB_0`) con el template:

   ```markdown
   # [Nombre de la acción]

   | Campo | Valor |
   |-------|-------|
   | **Fuente** | [Contenido origen + URL] |
   | **Estado** | 📌 En backlog |
   | **Bloqueador** | [Qué impide implementar ahora] |
   | **Proyecto target** | [Dónde se implementará] |
   | **Fecha backlog** | [Fecha actual] |
   | **Semana origen** | [WXX] |

   ## Resumen de investigación
   [Hallazgos del deep dive]

   ## Plan de implementación
   [Pasos concretos cuando el bloqueador se resuelva]

   ## Criterio de salida
   [Condición para salir del backlog]
   ```

9. **Subir consolidado actualizado** a Drive:
   ```bash
   gws drive files update --params '{"fileId": "ID_DEL_ARCHIVO"}' --upload /tmp/consolidado-semanal.md
   ```

10. **Recordatorio de Backlog** — SIEMPRE al final de la revisión, listar items en backlog:

    ```markdown
    ---

    ## 📌 Backlog (N items)

    | Item | Bloqueador | Target | Desde |
    |------|-----------|--------|-------|
    | GGA Pre-commit | Homebrew roto (Issue #49) | R&R | W10 |

    Revisa si algún bloqueador se resolvió.
    ```

    Para obtener los items, listar archivos en la carpeta Backlog de Drive:
    ```bash
    gws drive files list --params '{"q": "\"12_dxa67Tx4Z407PSRZ9y0VhlEPFRrB_0\" in parents and trashed=false", "fields": "files(id,name)"}'
    ```
    Y leer cada brief para extraer bloqueador y target.

11. **Limpiar archivos temporales.**

## Modo: Status (`--status`)

### Algoritmo

1. Descargar consolidado (mismo paso 1 de arriba)
2. Parsear TODAS las acciones (no solo pendientes)
3. Mostrar tabla completa con contadores:

   ```markdown
   ## Estado del Consolidado — WXX

   | # | Estado | Acción | Esfuerzo |
   |---|--------|--------|----------|
   | 1 | ✅ | ~~Instalar Engram~~ — 2026-03-05 | ⚡ |
   | 2 | 🎯 | Cooldown NPM | ⚡ |
   | 3 | ❌ | ~~Cursor Automations~~ | 📅 |
   | 4 | 📌 | GGA pre-commit — Homebrew roto | 📅 |
   | 5 | ⬜ | Nueva herramienta X | 📅 |

   **Totales:** 1 ✅ | 1 🎯 | 1 ❌ | 1 📌 | 1 ⬜
   ```

4. **Recordatorio de Backlog** (mismo paso 10 del modo Revisar)

5. NO modificar nada. Es solo lectura.

## Modo: Deep (`--deep N`)

### Algoritmo

1. Descargar consolidado
2. Identificar la acción número N
3. Buscar el contenido origen en la sección `## 📋 Contenidos` del consolidado
4. Extraer links de resumen y transcripción del contenido origen
5. **Descargar y leer el resumen** desde Drive (usar el link del consolidado para obtener el fileId)
6. **Descargar y leer la transcripción** si existe
7. **Buscar contexto adicional** en Engram (`mem_search` con keywords del tema)
8. **Investigar** cómo se aplica al stack actual de César:
   - Leer perfil profesional de Engram (`profile/cesar-moreno`)
   - Evaluar compatibilidad con proyectos actuales (Fuerza, R&R, Engagement)
   - Identificar alternativas si las hay

9. **Presentar informe:**

   ```markdown
   ## Deep Dive: [Nombre de la acción]

   **Fuente:** [Nombre del contenido] ([URL original])

   ### Qué es
   [Explicación concisa de la herramienta/patrón/concepto]

   ### Cómo aplica a tu stack
   | Proyecto | Aplicabilidad | Notas |
   |----------|--------------|-------|
   | Fuerza | Alta/Media/Baja | ... |
   | R&R | Alta/Media/Baja | ... |

   ### Implementación propuesta
   [Pasos concretos para implementar en tu contexto]

   ### Alternativas
   | Opción | Pros | Contras |
   |--------|------|---------|
   | ... | ... | ... |

   ### Esfuerzo real
   [Estimación basada en el análisis, no en el consolidado]

   ### Veredicto
   [Recomendación: adoptar / descartar / investigar más / enviar a backlog]
   ```

10. **César decide:** 🎯 adoptar | 📌 backlog (con bloqueador) | ❌ descartar (con razón) | 👁️ seguir pensando
11. Si 📌: crear brief en Backlog/ y actualizar consolidado
12. Actualizar consolidado y subir a Drive

## Reglas

- **NO modificar** el consolidado fuera de la sección de acciones
- **NO crear archivos locales** permanentes — solo temporales en /tmp
- **Respetar formato** de la guía: tachado para ❌/✅, razón obligatoria para ❌, fecha+dónde para ✅, bloqueador+brief para 📌
- **Silencioso en Drive:** No reportar detalles de upload/download, solo errores
- **Si el consolidado no existe:** Mostrar aviso y terminar
- **Si no hay acciones pendientes:** Mostrar resumen tipo --status y terminar
- **Links de Drive en consolidado:** Extraer fileId de la URL para descargar (formato: `https://drive.google.com/file/d/FILE_ID/view`)
- **SIEMPRE mostrar recordatorio de backlog** al final de cualquier modo (revisar, status, deep)
- **📌 solo después de deep dive** — no enviar a backlog sin investigación previa
