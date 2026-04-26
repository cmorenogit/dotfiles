---
name: gws-chat
description: Google Chat search and interaction via gws CLI. Use when user asks to read, search, or interact with Google Chat messages, spaces, or conversations. Triggers on keywords like chat, mensaje, conversacion, DM, espacio, Google Chat, menciones.
---

# Google Chat via gws CLI

Search and read Google Chat messages efficiently using the `gws` CLI tool.

## Key Info

- **Account:** cmoreno@dcanje.com
- **Timezone:** GMT-5 (America/Lima). API returns UTC — always subtract 5 hours for display.
- **Tool:** `gws` CLI with Chat API scopes

### Timezone Rules

1. **Display:** Always convert UTC to GMT-5 before showing times (subtract 5 hours).
2. **Filters:** When filtering "today" or date ranges, calculate UTC equivalent:
   - "Today" in GMT-5 starts at `YYYY-MM-DDT05:00:00Z` (current date in UTC)
   - Use `date -u -v+5H +%Y-%m-%dT05:00:00Z` or `python3 -c "from datetime import datetime, timedelta; now=datetime.utcnow()-timedelta(hours=5); print(now.strftime('%Y-%m-%dT') + '05:00:00Z')"` to compute dynamically
3. **Never hardcode dates** — always compute the UTC boundary from current local time.

## Quick Access Channels

### Product Team (AAAAfobEc28)
Primary work channel. 9 human members + 2 bots. Use as default for work mentions.

### Mantenimiento Nivel 2 Fuerza (AAQAMjc6GIs)
Support escalation channel. 10 human members.

## Spaces Reference

### Named Spaces (Groups)

| Space ID | Name | Type |
|----------|------|------|
| AAAAfobEc28 | Product Team | SPACE (9 members) |
| AAAAfsHQiss | +Apprecio | SPACE (97 members) |
| AAAAhSbMosY | Eng · Product Team (Ex SaaS TI) | SPACE |
| AAAAVj7w4uA | Apprecio Team Peru | SPACE |
| AAAAcB6mHBY | Fuerza pipelines | SPACE |
| AAQAMjc6GIs | Mantenimiento Nivel 2 Fuerza | SPACE |
| AAQAUx5L9e4 | Comunicacion TI - Productos | SPACE |
| AAQA6oEqWcI | Flujos AI agents | SPACE |

### Team DMs — Product Team Members

| Name | Role | User ID | DM Space ID |
|------|------|---------|-------------|
| Ignacio Valdovinos | Jefe Producto | 102600559492068881144 | 9nBLjcAAAAE |
| Nicole Fierro | QA + Doc | 113724492086510362927 | jCHJU8AAAAE |
| Julieth Ruiz | QA | 105837369684866007379 | rC85mCAAAAE |
| Faber Herrera | Dev (App + Desafios) | 112211994231617083712 | yFY4B8AAAAE |
| Kevin Acuna | Dev (App movil) | 105907356619822194289 | oYs5hCAAAAE |
| Diana (SaaS) | Reporta errores | 115802704722893639805 | ynvsjcAAAAE |
| Samuel (Alvarado?) | Soporte/Dev | 108399210587889233103 | hckCmSAAAAE |
| Ruben (Venegas) | Core legacy Fuerza | 116324056077885622751 | oaJX9cAAAAE |
| Stephanie (D'Angelo) | — | 114828342955466251726 | 0-K39cAAAAE |

### Other Known DMs

| Space ID | Contact | Notes |
|----------|---------|-------|
| hS3n6iAAAAE | Nicole (secondary/group) | Group DM |
| tzxNPiAAAAE | Unknown | Last msg: "Buenos dias Cesar" |

### Self

| Name | User ID |
|------|---------|
| Cesar Moreno | 115887578973909432984 |

## Commands

### List messages from a space

```bash
# Recent messages (newest first by default)
gws chat spaces messages list --params '{"parent": "spaces/SPACE_ID", "pageSize": 20}'

# Messages from today (compute UTC boundary dynamically)
TODAY_UTC=$(python3 -c "from datetime import datetime,timedelta; print((datetime.utcnow()-timedelta(hours=5)).strftime('%Y-%m-%dT')+'05:00:00Z')")
gws chat spaces messages list --params "{\"parent\": \"spaces/SPACE_ID\", \"pageSize\": 50, \"filter\": \"createTime > \\\"$TODAY_UTC\\\"\"}"

# Paginate all
gws chat spaces messages list --params '{"parent": "spaces/SPACE_ID", "pageSize": 50}' --page-all
```

### Quick access — Product Team today

```bash
# Compute today's start in UTC (GMT-5 → +5h offset)
TODAY_UTC=$(python3 -c "from datetime import datetime,timedelta; print((datetime.utcnow()-timedelta(hours=5)).strftime('%Y-%m-%dT')+'05:00:00Z')")
gws chat spaces messages list --params "{\"parent\": \"spaces/AAAAfobEc28\", \"pageSize\": 50, \"filter\": \"createTime > \\\"$TODAY_UTC\\\"\"}"
```

### Quick access — Mantenimiento Nivel 2

```bash
gws chat spaces messages list --params '{"parent": "spaces/AAQAMjc6GIs", "pageSize": 20}'
```

### Quick access — DM with someone

```bash
# Replace SPACE_ID with the DM Space ID from the table above
gws chat spaces messages list --params '{"parent": "spaces/SPACE_ID", "pageSize": 20}'
```

### Search messages containing text

Chat API does NOT support text search via filter. Use local filtering:

```bash
gws chat spaces messages list --params '{"parent": "spaces/SPACE_ID", "pageSize": 50}' --page-all 2>&1 | python3 -c "
import json, sys
for line in sys.stdin:
    data = json.loads(line)
    for m in data.get('messages', []):
        text = m.get('text', '') or ''
        if 'KEYWORD'.lower() in text.lower():
            created = m.get('createTime', '')[:19]
            sender = m.get('sender', {}).get('displayName', '?')
            print(f'[{created}] {sender}: {text[:200]}')
            print('---')
"
```

### Find @mentions of Cesar

Search across a specific space or multiple spaces:

```bash
gws chat spaces messages list --params '{"parent": "spaces/SPACE_ID", "pageSize": 50}' --page-all 2>&1 | python3 -c "
import json, sys
target_id = '115887578973909432984'  # Cesar's user ID
target_name = 'cesar'
for line in sys.stdin:
    data = json.loads(line)
    for m in data.get('messages', []):
        text = m.get('text', '') or ''
        annotations = m.get('annotations', [])
        mentioned = any(
            target_id in (a.get('userMention', {}).get('user', {}).get('name', '') or '')
            or target_name in (a.get('userMention', {}).get('user', {}).get('displayName', '') or '').lower()
            for a in annotations if a.get('type') == 'USER_MENTION'
        )
        if mentioned:
            created = m.get('createTime', '')[:19]
            sender = m.get('sender', {}).get('displayName', '?')
            print(f'[{created}] {sender}: {text[:200]}')
            print('---')
"
```

### Find @mentions across all key spaces

```bash
TODAY_UTC=$(python3 -c "from datetime import datetime,timedelta; print((datetime.utcnow()-timedelta(hours=5)).strftime('%Y-%m-%dT')+'05:00:00Z')")
for space_id in AAAAfobEc28 AAQAMjc6GIs AAAAhSbMosY AAAAfsHQiss; do
  echo "=== Space: $space_id ==="
  gws chat spaces messages list --params "{\"parent\": \"spaces/$space_id\", \"pageSize\": 50, \"filter\": \"createTime > \\\"$TODAY_UTC\\\"\"}" 2>&1 | python3 -c "
import json, sys
target_id = '115887578973909432984'
for line in sys.stdin:
    data = json.loads(line)
    for m in data.get('messages', []):
        annotations = m.get('annotations', [])
        mentioned = any(
            target_id in (a.get('userMention', {}).get('user', {}).get('name', '') or '')
            for a in annotations if a.get('type') == 'USER_MENTION'
        )
        if mentioned:
            created = m.get('createTime', '')[:19]
            sender = m.get('sender', {}).get('displayName', '?')
            text = m.get('text', '') or ''
            print(f'[{created}] {sender}: {text[:200]}')
            print('---')
"
done
```

### List space members

```bash
gws chat spaces members list --params '{"parent": "spaces/SPACE_ID", "pageSize": 50}'
```

### List spaces

```bash
gws chat spaces list --params '{"pageSize": 50}'
```

### Find a DM by checking last message

When DM members don't show displayName, identify by reading last message:

```bash
for space_id in ID1 ID2 ID3; do
  result=$(gws chat spaces messages list --params "{\"parent\": \"spaces/$space_id\", \"pageSize\": 1}" 2>&1)
  echo "$result" | python3 -c "
import json,sys
data=json.load(sys.stdin)
msgs=data.get('messages',[])
if msgs:
    t=msgs[0].get('text','')[:80]
    print(f'spaces/$space_id: {t}')
"
done
```

## Display Rules

1. **Always convert UTC to GMT-5** before showing times to user
2. **Format as table** when listing multiple messages
3. **DMs don't show sender names** — infer from context (alternating messages)
4. **Use --page-all** for comprehensive searches, plain list for recent messages
5. **Default space** for work mentions: Product Team (AAAAfobEc28)
6. **For "conversacion con X"** — look up DM Space ID in the table above, then list messages

## Common Queries

| User says | Action |
|-----------|--------|
| "mis menciones" / "me etiquetaron" | Find @mentions of Cesar across key spaces |
| "mensajes de hoy" | Filter by createTime > today UTC in Product Team |
| "conversacion con X" | Look up DM space ID in table, list messages |
| "que dice el chat" | Last 20 messages from Product Team |
| "busca X en el chat" | Text search with local grep in Product Team |
| "mensajes de Mantenimiento" | Last 20 from AAQAMjc6GIs |
| "DM con Ignacio/Nicole/Julieth" | Use mapped DM space ID directly |
| "quien me menciono hoy" | @mentions across all key spaces, today filter |
