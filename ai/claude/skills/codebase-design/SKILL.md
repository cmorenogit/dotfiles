---
name: codebase-design
description: Vocabulario compartido para diseñar deep modules — module, interface, depth, seam, adapter, leverage, locality, más los tests (deletion test, la interfaz es la superficie de test). Úsalo cuando se diseña o mejora la interfaz de un módulo, se decide dónde va un seam, se hace código más testeable o navegable por IA, o cuando otro skill necesita este vocabulario.
---

# Codebase Design

Diseñá **deep modules**: mucha conducta detrás de una interfaz chica, ubicada en un seam limpio, testeable a través de esa interfaz. Usá este lenguaje y estos principios dondequiera que se diseñe o reestructure código. El objetivo: leverage para los callers, locality para los mantenedores, y testabilidad para todos.

## Glosario

Usá estos términos **exacto** — no los sustituyas por "component", "service", "API" o "boundary". El lenguaje consistente es el punto entero.

**Module** — cualquier cosa con una interfaz y una implementación. Deliberadamente escala-agnóstico: una función, clase, paquete o slice que cruza capas. _Evitá_: unit, component, service.

**Interface** — todo lo que un caller debe saber para usar el módulo correctamente: la firma de tipos, pero también invariantes, restricciones de orden, modos de error, configuración requerida y características de performance. _Evitá_: API, signature (demasiado angostos — solo refieren a la superficie de tipos).

**Implementation** — lo que vive adentro de un módulo, su cuerpo de código. Distinto de **Adapter**: una cosa puede ser un adapter chico con una implementación grande (un repo Postgres) o un adapter grande con una implementación chica (un fake en memoria). Decí "adapter" cuando el seam es el tema; "implementation" en los demás casos.

**Depth** — leverage en la interfaz: cuánta conducta puede exercer un caller (o un test) por unidad de interfaz que tiene que aprender. Un módulo es **deep** cuando hay mucha conducta detrás de una interfaz chica, **shallow** cuando la interfaz es casi tan compleja como la implementación.

**Seam** _(Michael Feathers)_ — un lugar donde podés alterar la conducta sin editar en ese lugar; la *ubicación* donde vive la interfaz de un módulo. Dónde poner el seam es su propia decisión de diseño, distinta de qué va detrás. _Evitá_: boundary (sobrecargado con el bounded context de DDD).

**Adapter** — algo concreto que satisface una interfaz en un seam. Describe el *rol* (qué casilla llena), no la sustancia (qué tiene adentro).

**Leverage** — lo que los callers obtienen de la profundidad: más capacidad por unidad de interfaz que aprenden. Una implementación se paga sola a lo largo de N call sites y M tests.

**Locality** — lo que los mantenedores obtienen de la profundidad: el cambio, los bugs, el conocimiento y la verificación se concentran en un lugar en vez de desparramarse por los callers. Arreglá una vez, arreglado en todos lados.

## Deep vs shallow

**Deep module** = interfaz chica + mucha implementación:

```
┌─────────────────────┐
│   Interfaz chica    │  ← pocos métodos, params simples
├─────────────────────┤
│                     │
│  Implementación     │  ← lógica compleja escondida
│  profunda           │
└─────────────────────┘
```

**Shallow module** = interfaz grande + poca implementación (evitar):

```
┌─────────────────────────────────┐
│       Interfaz grande           │  ← muchos métodos, params complejos
├─────────────────────────────────┤
│  Implementación delgada         │  ← solo pasa de largo
└─────────────────────────────────┘
```

Al diseñar una interfaz, preguntá:

- ¿Puedo reducir la cantidad de métodos?
- ¿Puedo simplificar los parámetros?
- ¿Puedo esconder más complejidad adentro?

## Principios

- **La profundidad es propiedad de la interfaz, no de la implementación.** Un deep module puede estar compuesto internamente de partes chicas, mockeables, intercambiables — simplemente no son parte de la interfaz. Un módulo puede tener **seams internos** (privados a su implementación, usados por sus propios tests) además del **seam externo** en su interfaz.
- **El deletion test.** Imaginá borrar el módulo. Si la complejidad desaparece, era una pasarela. Si la complejidad reaparece repartida entre N callers, se ganaba el sueldo.
- **La interfaz es la superficie de test.** Callers y tests cruzan el mismo seam. Si querés testear *más allá* de la interfaz, el módulo probablemente tiene la forma equivocada.
- **Un adapter = seam hipotético. Dos adapters = seam real.** No metas un seam salvo que algo realmente varíe a través de él.

## Diseñar para testabilidad

Las buenas interfaces hacen el testing natural:

1. **Aceptá dependencias, no las crees.**

   ```typescript
   // Testeable
   function processOrder(order, paymentGateway) {}

   // Difícil de testear
   function processOrder(order) {
     const gateway = new StripeGateway();
   }
   ```

2. **Devolvé resultados, no produzcas side effects.**

   ```typescript
   // Testeable
   function calculateDiscount(cart): Discount {}

   // Difícil de testear
   function applyDiscount(cart): void {
     cart.total -= discount;
   }
   ```

3. **Superficie chica.** Menos métodos = menos tests. Menos params = setup de test más simple.

## Relaciones

- Un **Module** tiene exactamente una **Interface** (la superficie que presenta a callers y tests).
- **Depth** es una propiedad de un **Module**, medida contra su **Interface**.
- Un **Seam** es donde vive la **Interface** de un **Module**.
- Un **Adapter** se sienta en un **Seam** y satisface la **Interface**.
- **Depth** produce **Leverage** para los callers y **Locality** para los mantenedores.

## Framings rechazados

- **Depth como ratio de líneas-de-implementación a líneas-de-interfaz** (Ousterhout): premia inflar la implementación. Usamos depth-as-leverage en su lugar.
- **"Interface" como la keyword `interface` de TypeScript o los métodos públicos de una clase**: demasiado angosto — acá interface incluye todo hecho que un caller debe saber.
- **"Boundary"**: sobrecargado con el bounded context de DDD. Decí **seam** o **interface**.

## Para ir más profundo

- **Profundizar un cluster dadas sus dependencias** — ver [DEEPENING.md](DEEPENING.md): categorías de dependencia, disciplina de seams, y testing replace-don't-layer.
- **Explorar interfaces alternativas** — ver [DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md): levantá sub-agentes en paralelo para diseñar la interfaz de varias formas radicalmente distintas, después compará por depth, locality y ubicación del seam.
