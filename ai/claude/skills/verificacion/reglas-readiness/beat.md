# Readiness de review — Beat

Repos: front `ivaldovinos-app/ryr-39255` · back `ivaldovinos-app/apprecio-pulse`.
Reglas que un PR de Beat debe cumplir para el visto bueno técnico de César. Se verifican con `gh` (sin checkout).

| # | Regla | Cómo verificar | PASS si |
|---|---|---|---|
| 1 | Issue en **In Progress** | estado del issue en Linear | estado == In Progress (el owner lo pasa a Review después del visto bueno) |
| 2 | **Par de PRs** app + BO con el **mismo nombre de rama** | `gh pr list --repo <front> --head <branch>` y `--repo <back> --head <branch>` | existen ambos PRs con el mismo `headRefName` |
| 3 | Labels **`deploy:staging`** + **`deploy:preview`** | `gh pr view <PR> --json labels` | ambos labels presentes en el PR |
| 4 | **ADLC Gate = PASSED** | `gh pr view <PR> --json comments` → comentario del bot "ADLC Gate Results" | la línea final dice `Gate: PASSED` (un `Risk ⚠️` no bloquea si el gate pasó) |
| 5 | **Mergeable** | `gh pr view <PR> --json mergeable,mergeStateStatus` | `mergeable == MERGEABLE` (ignorar `mergeStateStatus: BLOCKED` — es branch protection, no conflicto) |

Notas:
- El preview del **front no levanta solo**: requiere el PR del **back** con label `deploy:preview`.
- pr-review de los PRs es **opcional** (el code-review de Ignacio normalmente levanta esas observaciones).
- Si falta algo → **devolución de readiness** ("falta X para revisar"), no review de fondo.
