# Deepening

Cómo profundizar un cluster de módulos shallow con seguridad, dadas sus dependencias. Asume el vocabulario de [SKILL.md](SKILL.md) — **module**, **interface**, **seam**, **adapter**.

## Categorías de dependencia

Al evaluar un candidato a profundizar, clasificá sus dependencias. La categoría determina cómo se testea el módulo profundizado a través de su seam.

### 1. In-process

Computación pura, estado en memoria, sin I/O. Siempre profundizable — fusioná los módulos y testeá a través de la nueva interfaz directamente. No hace falta adapter.

### 2. Local-substitutable

Dependencias que tienen stand-ins locales para test (PGLite para Postgres, filesystem en memoria). Profundizable si el stand-in existe. El módulo profundizado se testea con el stand-in corriendo en la suite de tests. El seam es interno; sin port en la interfaz externa del módulo.

### 3. Remote but owned (Ports & Adapters)

Tus propios servicios cruzando un boundary de red (microservicios, APIs internas). Definí un **port** (interfaz) en el seam. El deep module es dueño de la lógica; el transporte se inyecta como un **adapter**. Los tests usan un adapter en memoria. Producción usa un adapter HTTP/gRPC/queue.

Forma de la recomendación: *"Definí un port en el seam, implementá un adapter HTTP para producción y un adapter en memoria para testing, así la lógica vive en un solo deep module aunque esté desplegada a través de una red."*

### 4. True external (Mock)

Servicios de terceros (Stripe, Twilio, etc.) que no controlás. El módulo profundizado toma la dependencia externa como un port inyectado; los tests proveen un mock adapter.

## Disciplina de seams

- **Un adapter = seam hipotético. Dos adapters = seam real.** No introduzcas un port salvo que se justifiquen al menos dos adapters (típicamente producción + test). Un seam de un solo adapter es solo indirección.
- **Seams internos vs seams externos.** Un deep module puede tener seams internos (privados a su implementación, usados por sus propios tests) además del seam externo en su interfaz. No expongas seams internos a través de la interfaz solo porque los tests los usan.

## Estrategia de testing: replace, don't layer

- Los viejos unit tests sobre módulos shallow se vuelven desperdicio una vez que existen tests en la interfaz del módulo profundizado — borralos.
- Escribí tests nuevos en la interfaz del módulo profundizado. La **interfaz es la superficie de test**.
- Los tests afirman sobre resultados observables a través de la interfaz, no sobre estado interno.
- Los tests deben sobrevivir refactors internos — describen conducta, no implementación. Si un test tiene que cambiar cuando cambia la implementación, está testeando más allá de la interfaz.
