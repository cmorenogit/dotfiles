---
name: linear-scan
description: Foto rápida del inbox de Linear — qué te mencionan y qué se movió, en GMT-5, lista para /loop.
disable-model-invocation: true
---

# linear-scan — foto del inbox

Corré el script y mostrá su salida **tal cual**. Ya viene formateada, en GMT-5 y con sello de caducidad — no la reinterpretes, no la resumas, no la reordenes. El script es la fuente determinista; vos solo lo disparás.

```sh
bash ~/.claude/skills/linear-scan/scan.sh        # delta desde tu último scan
bash ~/.claude/skills/linear-scan/scan.sh --since 3d   # panorama de una ventana
```

Reenviá los args que haya dado el usuario.

- **sin args** → *delta*: solo lo llegado desde tu último scan; avanza el cursor. Ideal para `/loop`.
- **`--since 24h|3d|7d`** → panorama de esa ventana; **no** toca el cursor.

`✓ Sin novedades desde …` es éxito, no error: el inbox está al día hasta la hora sellada.

## Qué es — y qué no

*scan* = **detectar + mostrar**, nada más. Colapsa por issue: 🔔 menciones/asignaciones y 📋 novedad en tus issues (el ruido —reacciones, borrados— queda fuera).

No hace triage ni redacta respuesta. Si una mención merece entenderse → `/linear-lore <ID>`; responder → `/linear-respond <ID>`.

## Loop

```
/loop 30m /linear-scan
```

*freshness*: la foto caduca. Cada corrida trae solo lo nuevo y re-sella la hora.
