---
name: git-commit-helper
description: Generate descriptive commit messages in Spanish by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.
---

# Git Commit Helper

## Quick start

Analyze staged changes and generate commit message:

```bash
# View staged changes
git diff --staged

# Generate commit message based on changes
# (Claude will analyze the diff and suggest a message in Spanish)
```

## Commit message format

Follow conventional commits format with Spanish descriptions:

```
<type>(<scope>): <descripcion en español>

[cuerpo opcional en español]

[footer opcional]
```

### Types

- **feat**: Nueva funcionalidad
- **fix**: Corrección de bug
- **docs**: Cambios en documentación
- **style**: Cambios de estilo de código (formato, punto y coma)
- **refactor**: Refactorización de código
- **test**: Agregar o actualizar tests
- **chore**: Tareas de mantenimiento

### Examples

**Feature commit:**
```
feat(auth): agregar autenticación JWT

Implementar sistema de autenticación basado en JWT con:
- Endpoint de login con generación de token
- Middleware de validación de token
- Soporte para refresh token
```

**Bug fix:**
```
fix(api): manejar valores null en perfil de usuario

Prevenir crashes cuando campos del perfil son null.
Agregar validaciones antes de acceder a propiedades anidadas.
```

**Refactor:**
```
refactor(database): simplificar query builder

Extraer patrones de queries comunes en funciones reutilizables.
Reducir duplicación de código en capa de base de datos.
```

## Analyzing changes

Review what's being committed:

```bash
# Show files changed
git status

# Show detailed changes
git diff --staged

# Show statistics
git diff --staged --stat

# Show changes for specific file
git diff --staged path/to/file
```

## Commit message guidelines

**DO:**
- Usar modo imperativo ("agregar feature" no "agregué feature")
- Mantener primera línea bajo 50 caracteres
- Primera letra mayúscula en descripción
- Sin punto al final del resumen
- Explicar el POR QUÉ, no solo el QUÉ en el body

**DON'T:**
- Mensajes vagos como "actualizar" o "arreglar cosas"
- Incluir detalles técnicos de implementación en el resumen
- Escribir párrafos en la línea de resumen
- Usar tiempo pasado

## Multi-file commits

When committing multiple related changes:

```
refactor(core): reestructurar módulo de autenticación

- Mover lógica de auth de controllers a service layer
- Extraer validación en validators separados
- Actualizar tests para usar nueva estructura
- Agregar tests de integración para flujo de auth

Breaking change: Auth service ahora requiere objeto de configuración
```

## Scope examples

**Frontend:**
- `feat(ui): agregar spinner de carga al dashboard`
- `fix(form): validar formato de email`

**Backend:**
- `feat(api): agregar endpoint de perfil de usuario`
- `fix(db): resolver leak en pool de conexiones`

**Infrastructure:**
- `chore(ci): actualizar Node a versión 20`
- `feat(docker): agregar build multi-stage`

## Breaking changes

Indicate breaking changes clearly:

```
feat(api)!: reestructurar formato de respuesta API

BREAKING CHANGE: Todas las respuestas API ahora siguen spec JSON:API

Formato anterior:
{ "data": {...}, "status": "ok" }

Formato nuevo:
{ "data": {...}, "meta": {...} }

Guía de migración: Actualizar código cliente para manejar nueva estructura
```

## Template workflow

1. **Revisar cambios**: `git diff --staged`
2. **Identificar tipo**: ¿Es feat, fix, refactor, etc.?
3. **Determinar scope**: ¿Qué parte del código afecta?
4. **Escribir resumen**: Breve, imperativo, en español
5. **Agregar body**: Explicar por qué y qué impacto tiene
6. **Notar breaking changes**: Si aplica

## Interactive commit helper

Use `git add -p` for selective staging:

```bash
# Stage changes interactively
git add -p

# Review what's staged
git diff --staged

# Commit with message
git commit -m "type(scope): descripcion en español"
```

## Amending commits

Fix the last commit message:

```bash
# Amend commit message only
git commit --amend

# Amend and add more changes
git add forgotten-file.js
git commit --amend --no-edit
```

## Best practices

1. **Commits atómicos** - Un cambio lógico por commit
2. **Probar antes de commit** - Asegurar que el código funciona
3. **Referenciar issues** - Incluir números de issue si aplica
4. **Mantener foco** - No mezclar cambios no relacionados
5. **Escribir para humanos** - Tu yo del futuro leerá esto

## Commit message checklist

- [ ] Tipo es apropiado (feat/fix/docs/etc.)
- [ ] Scope es específico y claro
- [ ] Resumen tiene menos de 50 caracteres
- [ ] Resumen usa modo imperativo
- [ ] Body explica el POR QUÉ, no solo el QUÉ
- [ ] Breaking changes están claramente marcados
- [ ] Números de issue relacionados están incluidos
