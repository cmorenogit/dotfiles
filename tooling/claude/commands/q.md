Use the meeting-scribe MCP tool `brief(minutes=3)` to get recent meeting context. If the MCP tool is not available, read ~/meetings/current.md directly and filter the last 3 minutes by timestamps.

## Internal State (maintain across /q calls)

Track these internally — do NOT output them, but use them to avoid repetition:
- **Last timestamp seen**: remember the last timestamp from previous /q call
- **Ignacio's mode**: listening | teaching | correcting | asking-for-input | showing-data
- **Pending actions for César**: accumulate across calls

## Analysis Steps

1. **Filter NEW content only** — skip anything before the last timestamp you already reported
2. **Detect speaker mode** — is Ignacio teaching, correcting someone, asking César to speak, or showing data?
3. **Find real questions** — ignore rhetorical questions (¿cierto?, ¿ok?) and greetings. Only surface questions that need César to think or respond
4. **Determine if César needs to act NOW** — is he being asked to speak? Is there a moment to intervene?

## Output format (STRICT — follow exactly):

### If César needs to speak NOW:

🎯 **DI ESTO:** "[exact phrase to say — 1-2 sentences max]"

📌 **Nuevo:** [only what changed since last capture, 2-3 bullets max]

⚠️ **Cuidado:** [warning about Ignacio's mode or trap to avoid, if any]

### If real questions found (that César should answer):

> **Q:** "[question verbatim]"

🎯 **Responde:** [1-2 bullet points, direct answer]

📌 **Nuevo:** [what changed since last capture]

### If no questions and César doesn't need to speak:

📌 **Nuevo:**
- [new topic/decision/data point 1]
- [new topic/decision/data point 2]

📝 **Acumula:** [action item or insight to remember for later]

### ALWAYS end with:

`📡 [first_timestamp] → [last_timestamp] (X min)`

## Rules

- **MAX 8 lines of output** — I'm reading this during a live meeting
- **NEVER repeat** content from previous captures — only NEW information
- **1 recommendation, not 5** — if I need to speak, tell me THE BEST thing to say
- **Detect danger** — if Ignacio is in "correction mode" or "prove it with data mode", warn me before I propose something without evidence
- **No tables unless essential** — bullet points are faster to scan
- **Skip audio artifacts** — ignore repeated "Él" patterns, these are transcription noise
- Keep it SHORT — I need to respond in seconds, not minutes.
