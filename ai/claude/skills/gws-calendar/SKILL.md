---
name: gws-calendar
description: Google Calendar management via gws CLI. Use when user asks about meetings, events, schedule, availability, or calendar. Triggers on keywords like calendario, reunion, evento, agenda, horario, disponibilidad, meeting, schedule, cuando, manana, semana, lunes, martes, hoy tengo.
---

# Google Calendar via gws CLI

Manage calendar events, check availability, and schedule meetings using the `gws` CLI tool.

## Key Info

- **Account:** cmoreno@dcanje.com
- **Calendar ID:** primary (cmoreno@dcanje.com)
- **Timezone:** America/Lima (GMT-5). Use `-05:00` offset in dateTime fields.
- **Tool:** `gws` CLI with Calendar API scope

### Timezone Rules

1. **Event times:** Use `-05:00` offset in dateTime (e.g., `2026-03-05T09:00:00-05:00`)
2. **Filters (timeMin/timeMax):** Compute UTC dynamically:
   - Today start: `YYYY-MM-DDT05:00:00Z`
   - Use `python3 -c "from datetime import datetime,timedelta; d=datetime.now(datetime.timezone(timedelta(hours=-5))); print(d.strftime('%Y-%m-%dT')+'05:00:00Z')"`
3. **Display:** Always show times in GMT-5 to user.

## Recurring Meetings

| Meeting | Day | Time (GMT-5) | Attendees |
|---------|-----|-------------|-----------|
| Checkpoint Product Team | Varies | 09:00-10:00 | 8 members |

## Commands

### View today's events

```bash
TODAY_START=$(python3 -c "from datetime import datetime,timezone,timedelta; d=datetime.now(timezone(timedelta(hours=-5))); print(d.strftime('%Y-%m-%dT')+'05:00:00Z')")
TODAY_END=$(python3 -c "from datetime import datetime,timezone,timedelta; d=datetime.now(timezone(timedelta(hours=-5)))+timedelta(days=1); print(d.strftime('%Y-%m-%dT')+'05:00:00Z')")
gws calendar events list --params "{\"calendarId\": \"primary\", \"timeMin\": \"$TODAY_START\", \"timeMax\": \"$TODAY_END\", \"singleEvents\": true, \"orderBy\": \"startTime\"}" 2>&1 | python3 -c "
import json,sys
from datetime import datetime,timedelta,timezone
d=json.load(sys.stdin)
gmt5=timezone(timedelta(hours=-5))
for e in d.get('items',[]):
    raw = e.get('start',{}).get('dateTime','') or e.get('start',{}).get('date','')
    if 'T' in raw:
        dt = datetime.fromisoformat(raw).astimezone(gmt5)
        start = dt.strftime('%H:%M')
        end_raw = e.get('end',{}).get('dateTime','')
        end_dt = datetime.fromisoformat(end_raw).astimezone(gmt5)
        end = end_dt.strftime('%H:%M')
        time_str = f'{start}-{end}'
    else:
        time_str = 'Todo el dia'
    summary = e.get('summary','(sin titulo)')
    meet = e.get('hangoutLink','')
    meet_str = f' | {meet}' if meet else ''
    print(f'{time_str} | {summary}{meet_str}')
"
```

### View tomorrow's events

```bash
TOM_START=$(python3 -c "from datetime import datetime,timezone,timedelta; d=datetime.now(timezone(timedelta(hours=-5)))+timedelta(days=1); print(d.strftime('%Y-%m-%dT')+'05:00:00Z')")
TOM_END=$(python3 -c "from datetime import datetime,timezone,timedelta; d=datetime.now(timezone(timedelta(hours=-5)))+timedelta(days=2); print(d.strftime('%Y-%m-%dT')+'05:00:00Z')")
gws calendar events list --params "{\"calendarId\": \"primary\", \"timeMin\": \"$TOM_START\", \"timeMax\": \"$TOM_END\", \"singleEvents\": true, \"orderBy\": \"startTime\"}"
```

### View this week's events

```bash
WEEK_START=$(python3 -c "
from datetime import datetime,timezone,timedelta
gmt5=timezone(timedelta(hours=-5))
now=datetime.now(gmt5)
monday=now - timedelta(days=now.weekday())
print(monday.strftime('%Y-%m-%dT')+'05:00:00Z')
")
WEEK_END=$(python3 -c "
from datetime import datetime,timezone,timedelta
gmt5=timezone(timedelta(hours=-5))
now=datetime.now(gmt5)
sunday=now + timedelta(days=6-now.weekday())
print(sunday.strftime('%Y-%m-%dT')+'05:00:00Z')
")
gws calendar events list --params "{\"calendarId\": \"primary\", \"timeMin\": \"$WEEK_START\", \"timeMax\": \"$WEEK_END\", \"singleEvents\": true, \"orderBy\": \"startTime\"}"
```

### View specific date

```bash
# Replace YYYY-MM-DD with target date
gws calendar events list --params '{"calendarId": "primary", "timeMin": "YYYY-MM-DDT05:00:00Z", "timeMax": "YYYY-MM-DDT29:00:00Z", "singleEvents": true, "orderBy": "startTime"}'
```

### Search events by name

```bash
gws calendar events list --params '{"calendarId": "primary", "q": "KEYWORD", "timeMin": "2026-01-01T00:00:00Z", "singleEvents": true, "orderBy": "startTime", "maxResults": 10}'
```

### Get event details

```bash
gws calendar events get --params '{"calendarId": "primary", "eventId": "EVENT_ID"}'
```

### Create event

```bash
# Simple event
gws calendar events insert --params '{"calendarId": "primary"}' --json '{
  "summary": "Event Title",
  "description": "Event description",
  "start": {"dateTime": "2026-03-06T10:00:00-05:00", "timeZone": "America/Lima"},
  "end": {"dateTime": "2026-03-06T11:00:00-05:00", "timeZone": "America/Lima"}
}'

# Event with attendees and Google Meet
gws calendar events insert --params '{"calendarId": "primary", "conferenceDataVersion": 1}' --json '{
  "summary": "Reunion con equipo",
  "start": {"dateTime": "2026-03-06T10:00:00-05:00", "timeZone": "America/Lima"},
  "end": {"dateTime": "2026-03-06T11:00:00-05:00", "timeZone": "America/Lima"},
  "attendees": [
    {"email": "ivaldovinos@apprecio.com"},
    {"email": "jruiz@dcanje.com"}
  ],
  "conferenceData": {
    "createRequest": {"requestId": "meet-unique-id", "conferenceSolutionKey": {"type": "hangoutsMeet"}}
  }
}'

# All-day event
gws calendar events insert --params '{"calendarId": "primary"}' --json '{
  "summary": "Reminder",
  "start": {"date": "2026-03-06"},
  "end": {"date": "2026-03-07"}
}'
```

### Update event

```bash
# Update title or time
gws calendar events patch --params '{"calendarId": "primary", "eventId": "EVENT_ID"}' --json '{
  "summary": "New Title"
}'

# Reschedule
gws calendar events patch --params '{"calendarId": "primary", "eventId": "EVENT_ID"}' --json '{
  "start": {"dateTime": "2026-03-06T14:00:00-05:00", "timeZone": "America/Lima"},
  "end": {"dateTime": "2026-03-06T15:00:00-05:00", "timeZone": "America/Lima"}
}'

# Add attendees
gws calendar events patch --params '{"calendarId": "primary", "eventId": "EVENT_ID"}' --json '{
  "attendees": [
    {"email": "existing@email.com"},
    {"email": "new@email.com"}
  ]
}'
```

### Delete event

```bash
gws calendar events delete --params '{"calendarId": "primary", "eventId": "EVENT_ID"}'
```

### Check availability (free/busy)

```bash
gws calendar freebusy query --json '{
  "timeMin": "2026-03-06T05:00:00Z",
  "timeMax": "2026-03-07T05:00:00Z",
  "timeZone": "America/Lima",
  "items": [{"id": "primary"}]
}' 2>&1 | python3 -c "
import json,sys
from datetime import datetime,timedelta,timezone
d=json.load(sys.stdin)
gmt5=timezone(timedelta(hours=-5))
busy = d.get('calendars',{}).get('primary',{}).get('busy',[])
if not busy:
    print('Dia libre - sin reuniones')
else:
    print('Bloques ocupados:')
    for b in busy:
        s=datetime.fromisoformat(b['start']).astimezone(gmt5).strftime('%H:%M')
        e=datetime.fromisoformat(b['end']).astimezone(gmt5).strftime('%H:%M')
        print(f'  {s} - {e}')
"
```

### List calendars

```bash
gws calendar calendarList list --params '{"maxResults": 20}' 2>&1 | python3 -c "
import json,sys
d=json.load(sys.stdin)
for c in d.get('items',[]):
    print(f'{c.get(\"summary\",\"?\")} | {c.get(\"id\",\"?\")} | {c.get(\"accessRole\",\"?\")}')
"
```

## Team Email Reference

| Name | Email |
|------|-------|
| Ignacio Valdovinos | ivaldovinos@apprecio.com |
| Nicole Fierro | nfierro@dcanje.com |
| Julieth Ruiz | jruiz@dcanje.com |
| Faber Herrera | fherrera@apprecio.com |
| Kevin Acuna | kevinacuna@apprecio.com |
| Stephanie D'Angelo | sdangelo@dcanje.com |
| Diana Duran | dduran@apprecio.com |
| Samuel Alvarado | salvarado@apprecio.com |

## Common Queries

| User says | Action |
|-----------|--------|
| "que tengo hoy" / "mi agenda" | View today's events |
| "reuniones de manana" | View tomorrow's events |
| "agenda de la semana" | View this week's events |
| "estoy libre a las 3?" | Check free/busy for that time |
| "agenda reunion con X" | Create event with attendee |
| "mueve la reunion a las 4" | Update event time |
| "cancela la reunion" | Delete event |
| "cuando es el checkpoint" | Search events by name |
| "crea un meet con X" | Create event with Google Meet |
