---
name: gws-docs
description: Google Docs reading, creation, and editing via gws CLI. Use when user asks to read, create, edit, or extract content from Google Docs. Also for processing meeting transcriptions from Google Meet. Triggers on keywords like doc, documento, transcripcion, notas de reunion, Google Doc, meeting notes, crear documento, leer documento.
---

# Google Docs via gws CLI

Read, create, and manage Google Docs using the `gws` CLI tool.

## Key Info

- **Account:** cmoreno@dcanje.com
- **Tool:** `gws` CLI with Docs API scope
- **Meet Recordings folder:** 19ruxoV_h2P1WOqqx2_l1i4s9dkL7W4Tx

## Commands

### Read a Google Doc

The Docs API returns structured JSON. Extract plain text with:

```bash
gws docs documents get --params '{"documentId": "DOC_ID"}' 2>&1 | python3 -c "
import json, sys

def extract_text(doc):
    text = []
    for element in doc.get('body', {}).get('content', []):
        if 'paragraph' in element:
            for elem in element['paragraph'].get('elements', []):
                run = elem.get('textRun', {})
                if 'content' in run:
                    text.append(run['content'])
    return ''.join(text)

doc = json.load(sys.stdin)
print(f'Title: {doc.get(\"title\", \"?\")}\n')
print(extract_text(doc))
"
```

### Read doc metadata only (title, last modified)

```bash
gws docs documents get --params '{"documentId": "DOC_ID"}' 2>&1 | python3 -c "
import json,sys
doc = json.load(sys.stdin)
print(f'Title: {doc.get(\"title\",\"?\")}')
print(f'ID: {doc.get(\"documentId\",\"?\")}')
"
```

### Find Google Docs by name

```bash
gws drive files list --params '{"q": "mimeType=\"application/vnd.google-apps.document\" and name contains \"KEYWORD\"", "pageSize": 20, "fields": "files(id,name,modifiedTime)"}'
```

### Find recent Google Docs

```bash
TODAY=$(python3 -c "from datetime import datetime,timedelta; print((datetime.utcnow()-timedelta(hours=5)).strftime('%Y-%m-%dT')+'05:00:00')")
gws drive files list --params "{\"q\": \"mimeType='application/vnd.google-apps.document' and modifiedTime > '$TODAY'\", \"pageSize\": 20, \"fields\": \"files(id,name,modifiedTime)\"}"
```

### Find Meet transcriptions

```bash
# List Meet Recordings folder
gws drive files list --params '{"q": "\"19ruxoV_h2P1WOqqx2_l1i4s9dkL7W4Tx\" in parents", "pageSize": 20, "fields": "files(id,name,mimeType,modifiedTime)"}'

# Search transcriptions by keyword
gws drive files list --params '{"q": "\"19ruxoV_h2P1WOqqx2_l1i4s9dkL7W4Tx\" in parents and name contains \"KEYWORD\"", "pageSize": 20, "fields": "files(id,name,modifiedTime)"}'
```

### Create a new Google Doc

```bash
# Create empty doc
gws docs documents create --json '{"title": "Document Title"}'

# Create doc with initial content
gws docs documents create --json '{"title": "Document Title"}' 2>&1 | python3 -c "
import json,sys
doc = json.load(sys.stdin)
doc_id = doc['documentId']
print(f'Created: {doc_id}')
print(f'URL: https://docs.google.com/document/d/{doc_id}/edit')
"
```

### Add content to a Google Doc

```bash
# Insert text at the end (index 1 = start of doc)
gws docs documents batchUpdate --params '{"documentId": "DOC_ID"}' --json '{
  "requests": [
    {
      "insertText": {
        "location": {"index": 1},
        "text": "Your text content here\n"
      }
    }
  ]
}'
```

### Add formatted content (headings, bold, etc.)

```bash
# Insert heading + body text
gws docs documents batchUpdate --params '{"documentId": "DOC_ID"}' --json '{
  "requests": [
    {
      "insertText": {
        "location": {"index": 1},
        "text": "Heading Title\nBody text paragraph.\n"
      }
    },
    {
      "updateParagraphStyle": {
        "range": {"startIndex": 1, "endIndex": 15},
        "paragraphStyle": {"namedStyleType": "HEADING_1"},
        "fields": "namedStyleType"
      }
    }
  ]
}'
```

### Export Google Doc

```bash
# As plain text
gws drive files export --params '{"fileId": "DOC_ID", "mimeType": "text/plain"}'

# As PDF
gws drive files export --params '{"fileId": "DOC_ID", "mimeType": "application/pdf"}' > output.pdf

# As DOCX
gws drive files export --params '{"fileId": "DOC_ID", "mimeType": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"}' > output.docx
```

### Move doc to a folder

```bash
gws drive files update --params '{"fileId": "DOC_ID", "addParents": "FOLDER_ID", "removeParents": "OLD_FOLDER_ID"}'
```

## Transcription Workflow

For processing Google Meet transcriptions into weekly summaries:

1. **Find the transcription:**
```bash
gws drive files list --params '{"q": "\"19ruxoV_h2P1WOqqx2_l1i4s9dkL7W4Tx\" in parents and name contains \"Product\"", "pageSize": 5, "fields": "files(id,name,modifiedTime)", "orderBy": "modifiedTime desc"}'
```

2. **Read the transcription content:**
```bash
gws docs documents get --params '{"documentId": "DOC_ID"}' 2>&1 | python3 -c "
import json, sys
def extract_text(doc):
    text = []
    for element in doc.get('body', {}).get('content', []):
        if 'paragraph' in element:
            for elem in element['paragraph'].get('elements', []):
                run = elem.get('textRun', {})
                if 'content' in run:
                    text.append(run['content'])
    return ''.join(text)
doc = json.load(sys.stdin)
print(extract_text(doc))
"
```

3. **Save locally for /ingest processing:**
```bash
# Pipe to local file for ingest
gws docs documents get --params '{"documentId": "DOC_ID"}' 2>&1 | python3 -c "
import json, sys
def extract_text(doc):
    text = []
    for element in doc.get('body', {}).get('content', []):
        if 'paragraph' in element:
            for elem in element['paragraph'].get('elements', []):
                run = elem.get('textRun', {})
                if 'content' in run:
                    text.append(run['content'])
    return ''.join(text)
doc = json.load(sys.stdin)
print(extract_text(doc))
" > transcripts/YYYY-MM-DD-tipo-descripcion.md
```

## Common Queries

| User says | Action |
|-----------|--------|
| "lee el doc X" / "que dice el doc" | Read doc and extract plain text |
| "transcripcion de hoy" / "notas de la reunion" | Search Meet Recordings folder by date |
| "crea un documento" | Create new Google Doc |
| "escribe esto en un doc" | Create doc + batchUpdate with content |
| "exporta el doc como PDF" | Export via Drive files export |
| "busca documento de X" | Search Docs by name keyword |
| "documentos recientes" | Search by modifiedTime > today |
