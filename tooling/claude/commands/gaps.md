Use the meeting-scribe MCP tool `transcript()` to get the full meeting transcript. If the MCP tool is not available, read ~/meetings/current.md directly.

Analyze the ENTIRE transcript and identify:

1. **Temas que quedaron inconclusos** — se mencionó algo pero no se cerró, cambió de tema sin resolver
2. **Decisiones ambiguas** — se dijo algo pero no quedó claro el acuerdo o el responsable
3. **Preguntas sin respuesta** — alguien preguntó y no se respondió o la respuesta fue vaga
4. **Contradicciones** — dos afirmaciones que se oponen
5. **Compromisos vagos** — "lo vemos", "después hablamos", "hay que definir" sin fecha ni dueño

## Output format (STRICT):

**Gaps detectados en la reunión:**

🔴 **Sin resolver:**
- [tema/pregunta que no se cerró]
- [otro tema pendiente]

🟡 **Ambiguo:**
- [decisión o compromiso que no quedó claro]

🟢 **Cerrado pero verificar:**
- [algo que se acordó pero convendría confirmar]

**Sugerencia:** [1 línea con qué preguntar o aclarar antes de que termine la reunión]

`📡 Análisis: [first_timestamp] → [last_timestamp] (X segments)`

Keep it actionable — I need to raise these points before the meeting ends.
