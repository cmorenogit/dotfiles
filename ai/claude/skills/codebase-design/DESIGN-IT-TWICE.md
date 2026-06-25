# Design It Twice

Cuando el usuario quiere explorar interfaces alternativas para un candidato a profundizar elegido, usá este patrón de sub-agentes en paralelo. Basado en "Design It Twice" (Ousterhout) — tu primera idea es poco probable que sea la mejor.

Usa el vocabulario de [SKILL.md](SKILL.md) — **module**, **interface**, **seam**, **adapter**, **leverage**.

## Proceso

### 1. Encuadrá el espacio del problema

Antes de levantar sub-agentes, escribí una explicación —de cara al usuario— del espacio del problema para el candidato elegido:

- Las constraints que cualquier interfaz nueva tendría que satisfacer
- Las dependencias de las que dependería, y en qué categoría caen (ver [DEEPENING.md](DEEPENING.md))
- Un sketch de código ilustrativo y rústico para aterrizar las constraints — no una propuesta, solo una forma de hacer concretas las constraints

Mostralo al usuario, después seguí de inmediato al Paso 2. El usuario lee y piensa mientras los sub-agentes trabajan en paralelo.

### 2. Levantá sub-agentes

Levantá 3+ sub-agentes en paralelo con la herramienta Agent. Cada uno debe producir una interfaz **radicalmente distinta** para el módulo profundizado.

Promptá a cada sub-agente con un brief técnico separado (rutas de archivos, detalles de acoplamiento, categoría de dependencia de [DEEPENING.md](DEEPENING.md), qué vive detrás del seam). El brief es independiente de la explicación del espacio del problema del Paso 1. Dale a cada agente una constraint de diseño distinta:

- Agente 1: "Minimizá la interfaz — apuntá a 1–3 entry points máximo. Maximizá leverage por entry point."
- Agente 2: "Maximizá flexibilidad — soportá muchos casos de uso y extensión."
- Agente 3: "Optimizá para el caller más común — hacé que el caso default sea trivial."
- Agente 4 (si aplica): "Diseñá alrededor de ports & adapters para las dependencias que cruzan el seam."

Incluí en el brief tanto el vocabulario de [SKILL.md](SKILL.md) como el de CONTEXT.md, así cada sub-agente nombra las cosas de forma consistente con el lenguaje de arquitectura y el lenguaje de dominio del proyecto.

Cada sub-agente devuelve:

1. Interface (tipos, métodos, params — más invariantes, orden, modos de error)
2. Ejemplo de uso mostrando cómo la usan los callers
3. Qué esconde la implementación detrás del seam
4. Estrategia de dependencias y adapters (ver [DEEPENING.md](DEEPENING.md))
5. Trade-offs — dónde el leverage es alto, dónde es delgado

### 3. Presentá y compará

Presentá los diseños secuencialmente para que el usuario absorba cada uno, después compáralos en prosa. Contrastá por **depth** (leverage en la interfaz), **locality** (dónde se concentra el cambio) y **ubicación del seam**.

Tras comparar, dá tu propia recomendación: qué diseño te parece más fuerte y por qué. Si elementos de distintos diseños combinan bien, propuso un híbrido. Sé opinado — el usuario quiere una lectura fuerte, no un menú.
