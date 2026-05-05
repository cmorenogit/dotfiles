---
name: gws-drive
description: Google Drive file management via gws CLI. Use when user asks to find, list, create, upload, download, share, or organize files and folders in Google Drive. Triggers on keywords like drive, archivo, carpeta, compartir, compartido, subir, descargar, folder, documento, buscar archivo.
---

# Google Drive via gws CLI

Manage files, folders, and sharing in Google Drive using the `gws` CLI tool.

## Key Info

- **Account:** cmoreno@dcanje.com
- **Tool:** `gws` CLI with Drive API scope

## Known Folders

### Own Folders (root)

| Name | ID |
|------|-----|
| Apprecio | 1I41CH6j8JV9pndGnOa58hmEofpM7srGK |
| Meet Recordings | 19ruxoV_h2P1WOqqx2_l1i4s9dkL7W4Tx |
| Archivo | 1pDdCHiqRWTKRKBG8tfayN9nDj4np290E |

### Apprecio Subfolders

| Name | ID |
|------|-----|
| Fuerza | 146n912z3ZEM1EfwZ63CnFdTGuBUJfA_h |
| RyR | 14hq5GcwWK29RtruD0YWws0p4IBHOuvD5 |
| RyR/modulos | 1xXVpymbxvYJCOTMhJuHgjEgH1AtjMjVE |
| RyR/modulos/worklife | 1XQrhRsxGf1plN2CBTMNLYsRTitDE1mTK |
| Engagement | 18Mi1Wu5Rj4rMWxEjZpG7fjHsMPqpHPzr |
| Smart Loyalty | 18UbWcip7zhlZtajP0p-eh0UQ8jSbbyBB |
| Security | 1NoAfsJCZcfTNckd6ewSP0lK7nyZTTPHK |
| QA | 1gU2mM3Xld_P3JoSt3W5474FlXZ4h9t8I |
| General | 1Zn7t_dWRxWvzt5UoTyjpAtCcx1li95Gs |

### Key Shared Folders

| Name | Owner | ID |
|------|-------|-----|
| RyR Generalista | ivaldovinos@apprecio.com | 1nWo6_K3tAP5ELUJLUAnemIk_iduAYMeF |
| Test | kevinacuna@apprecio.com | 1no73xgY5eRAEgs_MF9ZXortweTKMgIFr |
| Documentos (Faber) | fherrera@apprecio.com | 1AakH2fU9txyJdwqMaHw72yVPJRi64JW1 |
| scaffolder - QA | sdangelo@dcanje.com | 1pPo0g2fPosVN1LCnYURJb5fGWA-YcPie |
| Personal Cesar | morenodev@gmail.com | 1-zwa8t251I5OCX1jLMC4D_rTdPlg53Jz |
| Personal Cesar/Conocimiento | morenodev@gmail.com | 1M6jnKtKUqbr6cdHqim3LcNj8G08jsDd2 |
| Personal Cesar/Conocimiento/Guías | morenodev@gmail.com | 1uep9BLEBsOhtVfaR5aajoMJWkNxRbwCW |
| Personal Cesar/Conocimiento/Consolidados | morenodev@gmail.com | 19LdECi9R2Ny6g_IwhTLvnXcXN21CCAo1 |
| Personal Cesar/Conocimiento/Consolidados/Backlog | morenodev@gmail.com | 12_dxa67Tx4Z407PSRZ9y0VhlEPFRrB_0 |
| Personal Cesar/Estado Semanal | morenodev@gmail.com | 11R8Pa7w_oquA_1MeiO7ZLHIXiti_Fb-Z |
| Personal Cesar/Estado Semanal/Archivo | morenodev@gmail.com | 1xWblzHCBKoT0RxzAo8JSyJD7MZ48sWha |

## Commands

### List files

```bash
# Root files
gws drive files list --params '{"pageSize": 20, "fields": "files(id,name,mimeType,modifiedTime,owners)"}'

# Root folders only
gws drive files list --params '{"q": "mimeType=\"application/vnd.google-apps.folder\" and \"root\" in parents", "pageSize": 20, "fields": "files(id,name)"}'

# Contents of a specific folder
gws drive files list --params '{"q": "\"FOLDER_ID\" in parents", "pageSize": 50, "fields": "files(id,name,mimeType,modifiedTime)"}'
```

### Search files

```bash
# By name
gws drive files list --params '{"q": "name contains \"KEYWORD\"", "pageSize": 20, "fields": "files(id,name,mimeType,modifiedTime)"}'

# By type (Google Docs)
gws drive files list --params '{"q": "mimeType=\"application/vnd.google-apps.document\"", "pageSize": 20, "fields": "files(id,name,modifiedTime)"}'

# By type (Google Sheets)
gws drive files list --params '{"q": "mimeType=\"application/vnd.google-apps.spreadsheet\"", "pageSize": 20, "fields": "files(id,name,modifiedTime)"}'

# Modified today (compute dynamically)
TODAY=$(python3 -c "from datetime import datetime,timedelta; print((datetime.utcnow()-timedelta(hours=5)).strftime('%Y-%m-%dT')+'05:00:00')")
gws drive files list --params "{\"q\": \"modifiedTime > '$TODAY'\", \"pageSize\": 20, \"fields\": \"files(id,name,mimeType,modifiedTime)\"}"

# Shared with me
gws drive files list --params '{"q": "sharedWithMe=true", "pageSize": 20, "fields": "files(id,name,mimeType,owners)"}'

# Shared folders
gws drive files list --params '{"q": "sharedWithMe=true and mimeType=\"application/vnd.google-apps.folder\"", "pageSize": 20, "fields": "files(id,name,owners)"}'
```

### Create folder

```bash
gws drive files create --json '{"name": "Folder Name", "mimeType": "application/vnd.google-apps.folder"}'

# Inside a parent folder
gws drive files create --json '{"name": "Folder Name", "mimeType": "application/vnd.google-apps.folder", "parents": ["PARENT_FOLDER_ID"]}'
```

### Upload file

```bash
# Upload to root
gws drive files create --json '{"name": "filename.md"}' --upload /path/to/file.md

# Upload to specific folder
gws drive files create --json '{"name": "filename.md", "parents": ["FOLDER_ID"]}' --upload /path/to/file.md
```

### Download file

```bash
# Download binary/text file
gws drive files get --params '{"fileId": "FILE_ID", "alt": "media"}' > output_file

# Export Google Doc as plain text
gws drive files export --params '{"fileId": "FILE_ID", "mimeType": "text/plain"}'

# Export Google Doc as PDF
gws drive files export --params '{"fileId": "FILE_ID", "mimeType": "application/pdf"}' > output.pdf

# Export Google Sheet as CSV
gws drive files export --params '{"fileId": "FILE_ID", "mimeType": "text/csv"}'
```

### Share file/folder

```bash
# Share with specific user (viewer)
gws drive permissions create --params '{"fileId": "FILE_ID"}' --json '{"role": "reader", "type": "user", "emailAddress": "user@email.com"}'

# Share with specific user (editor)
gws drive permissions create --params '{"fileId": "FILE_ID"}' --json '{"role": "writer", "type": "user", "emailAddress": "user@email.com"}'

# Share with specific user (commenter)
gws drive permissions create --params '{"fileId": "FILE_ID"}' --json '{"role": "commenter", "type": "user", "emailAddress": "user@email.com"}'

# Share with anyone who has the link (viewer)
gws drive permissions create --params '{"fileId": "FILE_ID"}' --json '{"role": "reader", "type": "anyone"}'

# List current permissions
gws drive permissions list --params '{"fileId": "FILE_ID"}'

# Remove permission
gws drive permissions delete --params '{"fileId": "FILE_ID", "permissionId": "PERMISSION_ID"}'
```

### Delete / Move to trash

```bash
# Move to trash (safe)
gws drive files update --params '{"fileId": "FILE_ID"}' --json '{"trashed": true}'
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
| Cesar Moreno (self) | cmoreno@dcanje.com |

## MIME Types Reference

| Type | MIME |
|------|------|
| Google Doc | application/vnd.google-apps.document |
| Google Sheet | application/vnd.google-apps.spreadsheet |
| Google Slides | application/vnd.google-apps.presentation |
| Folder | application/vnd.google-apps.folder |
| PDF | application/pdf |
| Markdown | text/markdown |

## Common Queries

| User says | Action |
|-----------|--------|
| "mis archivos" / "mi drive" | List root files |
| "carpetas compartidas" | Search sharedWithMe folders |
| "busca X en drive" | Search by name |
| "sube este archivo" | Upload with --upload |
| "comparte con X" | Create permission with email |
| "que hay en la carpeta X" | List folder contents by ID |
| "archivos de hoy" | Search by modifiedTime > today |
| "descarga el doc X" | Export as text/plain or get media |
