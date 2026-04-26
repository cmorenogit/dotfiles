---
description: SDD quick reference — comandos, flujo y cuándo usar cada uno
---

# SDD Quick Reference

Muestra la referencia rápida de Spec-Driven Development. No ejecuta nada, solo informa.

## Output

Responde con EXACTAMENTE este contenido (sin modificar, sin agregar):

```
# SDD — Quick Reference

## Diseño (pre-SDD, standalone)

| Comando | Qué hace | Cuándo usar |
|---------|----------|-------------|
| `/prd <name>` | Genera PRD desde Drive → Engram | Inicio de módulo nuevo |
| `/prd <name> --file <path>` | Genera PRD desde archivo local | Revisar PRD de otro dev |
| `/prd <name> --update` | Re-lee Drive y actualiza PRD existente | Cuando docs de Drive cambiaron |
| `/prd <name> --edit` | Edita PRD manualmente | Ajuste puntual |
| `/prd-review <name>` | Valida PRD (28 checks producto, score) | Después de /prd |
| `/module-design <name>` | Genera/edita arquitectura + wireframes | Después de prd-review |
| `/module-design-review <name>` | Valida arquitectura (34 checks técnicos) | Después de module-design |

## SDD (implementación)

| Comando | Qué hace | Cuándo usar |
|---------|----------|-------------|
| `/sdd-init` | Detecta stack del proyecto | Primera vez en un proyecto |
| `/sdd-explore <tema>` | Investiga codebase, compara enfoques | Investigación sin compromiso |
| `/sdd-new <name>` | [prd-review → module-design →] explora + propuesta | Iniciar feature nueva |
| `/sdd-ff <name>` | [prd-review → module-design →] spec + design + tasks | Planning completo |
| `/sdd-continue` | Ejecuta siguiente fase pendiente | No sé qué sigue |
| `/sdd-apply <name>` | Implementa en batches | Cuando tasks están listos |
| `/sdd-verify <name>` | Tests reales + compliance matrix | Después de implementar |
| `/sdd-archive <name>` | Merge specs + cierra cambio | Al final (opcional) |

Nota: [prd-review → module-design] son automáticos si existe PRD. Sin PRD, se saltan.

## Flujo Completo (módulo nuevo con PRD)

/prd rf → PRD desde Drive/archivo
        ↓
/sdd-new rf → prd-review + module-design + explora + propuesta → STOP
        ↓
(opcional) Prototipo visual → React estático desde wireframes del MDD
        ↓
/sdd-ff rf → spec + design + tasks → STOP
        ↓
/sdd-apply rf → implementa → /sdd-verify rf → /sdd-archive rf

## Flujos por Situación

| Situación | Comandos |
|-----------|----------|
| Módulo nuevo completo | `/prd` → `/sdd-ff` → `/sdd-apply` → `/sdd-verify` |
| Solo diseño + prototipo | `/prd` → `/prd-review` → `/module-design` → prototipo ad-hoc |
| Revisar PRD de otro dev | `/prd --file` → `/prd-review` |
| Diseño + orientar al equipo | `/prd` → `/prd-review` → `/module-design` |
| Feature mediana sin PRD | `/sdd-new` → `/sdd-apply` |
| Solo investigar | `/sdd-explore` |
| Fix / bug menor | No usar SDD |
| Refactor con impacto | `/sdd-explore` → `/sdd-new` (solo planning) |
| No sé qué sigue | `/sdd-continue` (él decide) |

## Cambio mid-implementation

/prd rf --edit → actualiza PRD
/sdd-continue rf → detecta cambio → re-review → update MDD → continúa

## Persistencia

Todo se guarda en Engram con naming: sdd/{change-name}/{tipo}
Tipos: prd, prd-review, module-design, module-design-review, explore, proposal, spec, design, tasks, apply-progress, verify-report
```

## Rules

- SOLO mostrar la referencia. NO ejecutar ningún comando SDD.
- NO agregar explicaciones extra. El output ES la referencia.
- Si el usuario pasa un argumento (ej: `/sdd help`), ignorarlo y mostrar la referencia igual.
