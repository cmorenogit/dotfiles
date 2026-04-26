---
name: rr-edge-function-patterns
description: Use when implementing or refactoring Edge Functions for R&R modules. Defines the standard architecture based on WorkLife patterns.
---

# R&R Edge Function Patterns

## Overview

Standard architecture for R&R module Edge Functions, based on the WorkLife reference
implementation. ALL new Edge Functions MUST follow this pattern. Existing modules
should be consolidated to match.

**Announce at start:** "I'm using the rr-edge-function-patterns skill for <MODULE> API implementation."

## Architecture: Consolidated API

### File Structure (mandatory)

```
supabase/functions/<module>-api/
├── index.ts              # Router + Service class (all endpoints)
├── errors.ts             # Centralized error catalog
├── validators.ts         # Centralized validation with field whitelists
├── state-machine.ts      # State transitions (if module has lifecycle states)
├── __tests__/
│   ├── unit/
│   │   ├── validators/   # Pure function tests for validators
│   │   ├── errors/       # Error handling tests
│   │   ├── state-machine/ # State transition tests
│   │   └── security/     # CWE-based security tests
│   ├── service/          # Integration tests with real DB
│   └── helpers/          # Test setup utilities
└── _shared/ -> ../../_shared/  # Symlink to shared utilities
```

### index.ts Pattern

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import { ERROR_CODES, AppError, throwAppError } from "./errors.ts";
import { validateCreate, validateUpdate, extractFields } from "./validators.ts";
import { validateTransition } from "./state-machine.ts";

// ============================================================
// <MODULE>-API ENDPOINTS:
//   GET    /<module>              -> list (with filters)
//   GET    /<module>/:id          -> get by id
//   POST   /<module>              -> create
//   PUT    /<module>/:id          -> update
//   POST   /<module>/:id/<action> -> lifecycle action
//   DELETE /<module>/:id          -> archive/soft delete
// ============================================================

class <Module>Service {
  private supabase;      // User-context client (RLS enforced)
  private supabaseAdmin; // Service-role client (audit, system ops)
  private userId: string;
  private tenantId: string;
  private userRole: string;

  constructor(req: Request) {
    const authHeader = req.headers.get("Authorization")!;
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // User-context client (RLS enforced)
    this.supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // Service-role client (audit, system operations)
    this.supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
  }

  // === AUTH HELPERS ===

  async init(): Promise<void> {
    const { data: { user }, error } = await this.supabase.auth.getUser();
    if (error || !user) throwAppError(ERROR_CODES.AUTH_REQUIRED);

    this.userId = user.id;
    this.tenantId = await this.getTenantId();
    this.userRole = await this.getUserRole();
  }

  private async getTenantId(): Promise<string> {
    const { data } = await this.supabase
      .from("user_roles")
      .select("tenant_id")
      .eq("user_id", this.userId)
      .single();
    if (!data) throwAppError(ERROR_CODES.TENANT_NOT_FOUND);
    return data.tenant_id;
  }

  private async getUserRole(): Promise<string> {
    const { data } = await this.supabase
      .from("user_roles")
      .select("role")
      .eq("user_id", this.userId)
      .eq("tenant_id", this.tenantId)
      .single();
    return data?.role || "user";
  }

  private isAdminOrManager(): boolean {
    return ["admin", "manager"].includes(this.userRole);
  }

  private requireAdminOrManager(): void {
    if (!this.isAdminOrManager()) {
      throwAppError(ERROR_CODES.UNAUTHORIZED_ROLE);
    }
  }

  // === CRUD OPERATIONS ===
  // Each method validates input, checks auth, executes, audits

  async list(url: URL): Promise<Response> { /* ... */ }
  async getById(id: string): Promise<Response> { /* ... */ }

  async create(body: unknown): Promise<Response> {
    this.requireAdminOrManager();
    const validated = validateCreate(body); // Validates + whitelists fields
    // INSERT only validated fields, NEVER spread raw body
    // Log audit event
  }

  async update(id: string, body: unknown): Promise<Response> {
    this.requireAdminOrManager();
    const validated = validateUpdate(body); // Validates + whitelists fields
    // UPDATE only validated fields
    // Log audit event
  }

  // === LIFECYCLE OPERATIONS ===

  async transition(id: string, targetStatus: string): Promise<Response> {
    this.requireAdminOrManager();
    // 1. Get current status
    // 2. validateTransition(current, target, this.userRole)
    // 3. Execute transition
    // 4. Log audit event
  }

  // === AUDIT ===

  private async logAudit(
    eventType: string,
    entityId: string,
    data: Record<string, unknown>
  ): Promise<void> {
    await this.supabaseAdmin.from("<module>_audit").insert({
      tenant_id: this.tenantId,
      user_id: this.userId,
      event_type: eventType,
      entity_id: entityId,
      data,
      created_at: new Date().toISOString(),
    });
  }
}

// === ROUTER ===

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors(req);

  try {
    const service = new <Module>Service(req);
    await service.init();

    const url = new URL(req.url);
    const pathParts = url.pathname.split("/").filter(Boolean);
    // pathParts[0] = function name, pathParts[1] = resource, pathParts[2] = id, etc.

    // Route matching based on method + path
    // ...

  } catch (error) {
    if (error instanceof AppError) {
      return new Response(
        JSON.stringify({ success: false, error: error.message, code: error.code }),
        { status: error.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    console.error("Unhandled error:", error);
    return new Response(
      JSON.stringify({ success: false, error: "Error interno del servidor" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
```

### errors.ts Pattern

```typescript
export const ERROR_CODES = {
  // Auth errors (401, 403)
  AUTH_REQUIRED: "AUTH_REQUIRED",
  UNAUTHORIZED_ROLE: "UNAUTHORIZED_ROLE",
  TENANT_NOT_FOUND: "TENANT_NOT_FOUND",
  TENANT_MISMATCH: "TENANT_MISMATCH",

  // Resource errors (404, 409)
  NOT_FOUND: "<MODULE>_NOT_FOUND",
  ALREADY_EXISTS: "<MODULE>_ALREADY_EXISTS",

  // State errors (409)
  INVALID_TRANSITION: "INVALID_STATE_TRANSITION",
  INVALID_STATUS: "INVALID_STATUS",

  // Validation errors (400)
  INVALID_INPUT: "INVALID_INPUT",
  MISSING_FIELD: "MISSING_REQUIRED_FIELD",
  INVALID_FIELD_VALUE: "INVALID_FIELD_VALUE",

  // Business logic errors (422)
  BUSINESS_RULE_VIOLATION: "BUSINESS_RULE_VIOLATION",

  // DB errors (500)
  DB_ERROR: "DATABASE_ERROR",
} as const;

export type ErrorCode = typeof ERROR_CODES[keyof typeof ERROR_CODES];

export const ERROR_MESSAGES: Record<string, { message: string; status: number }> = {
  [ERROR_CODES.AUTH_REQUIRED]: {
    message: "Autenticacion requerida",
    status: 401,
  },
  [ERROR_CODES.UNAUTHORIZED_ROLE]: {
    message: "No tienes permisos para esta accion",
    status: 403,
  },
  [ERROR_CODES.TENANT_NOT_FOUND]: {
    message: "Tenant no encontrado para el usuario",
    status: 403,
  },
  [ERROR_CODES.TENANT_MISMATCH]: {
    message: "No perteneces a este tenant",
    status: 403,
  },
  [ERROR_CODES.NOT_FOUND]: {
    message: "Recurso no encontrado",
    status: 404,
  },
  [ERROR_CODES.ALREADY_EXISTS]: {
    message: "El recurso ya existe",
    status: 409,
  },
  [ERROR_CODES.INVALID_TRANSITION]: {
    message: "Transicion de estado no permitida: {from} -> {to}",
    status: 409,
  },
  [ERROR_CODES.INVALID_INPUT]: {
    message: "Datos de entrada invalidos: {details}",
    status: 400,
  },
  [ERROR_CODES.MISSING_FIELD]: {
    message: "Campo requerido faltante: {field}",
    status: 400,
  },
  // ... one entry per error code
};

export class AppError extends Error {
  code: string;
  status: number;

  constructor(code: string, variables?: Record<string, string>) {
    const template = ERROR_MESSAGES[code] || {
      message: "Error desconocido",
      status: 500,
    };
    let message = template.message;
    if (variables) {
      for (const [key, value] of Object.entries(variables)) {
        message = message.replace(`{${key}}`, value);
      }
    }
    super(message);
    this.code = code;
    this.status = template.status;
  }
}

export function throwAppError(
  code: string,
  variables?: Record<string, string>
): never {
  throw new AppError(code, variables);
}

export function isAppError(error: unknown): error is AppError {
  return error instanceof AppError;
}

// Translate common PostgreSQL errors to AppErrors
export function translateDbError(error: { code?: string; message?: string }): AppError {
  if (error.code === "23505") return new AppError(ERROR_CODES.ALREADY_EXISTS);
  if (error.code === "23503") return new AppError(ERROR_CODES.NOT_FOUND);
  return new AppError(ERROR_CODES.DB_ERROR);
}
```

### validators.ts Pattern

```typescript
// === FIELD WHITELISTS (prevents CWE-915 Mass Assignment) ===

export const CREATE_FIELDS = [
  "name", "description", "family", "type",
  // ... all allowed fields for creation
] as const;

export const UPDATE_FIELDS = [
  "name", "description",
  // ... all allowed fields for updates (subset of create)
] as const;

// === FIELD EXTRACTION (safe) ===

export function extractFields<T extends Record<string, unknown>>(
  body: Record<string, unknown>,
  allowedFields: readonly string[]
): Partial<T> {
  const result: Record<string, unknown> = {};
  for (const field of allowedFields) {
    if (body[field] !== undefined) {
      result[field] = body[field];
    }
  }
  return result as Partial<T>;
}

// === PURE VALIDATION FUNCTIONS (exported for unit testing) ===

export function validateCreate(body: unknown): Record<string, unknown> {
  if (!body || typeof body !== "object") {
    throwAppError(ERROR_CODES.INVALID_INPUT, { details: "Body must be an object" });
  }

  const raw = body as Record<string, unknown>;

  // Required fields check
  const required = ["name"]; // Module-specific required fields
  for (const field of required) {
    if (!raw[field]) {
      throwAppError(ERROR_CODES.MISSING_FIELD, { field });
    }
  }

  // Type validation per field
  if (raw.name && typeof raw.name !== "string") {
    throwAppError(ERROR_CODES.INVALID_FIELD_VALUE, { field: "name" });
  }

  // Extract ONLY whitelisted fields
  return extractFields(raw, CREATE_FIELDS);
}

export function validateUpdate(body: unknown): Record<string, unknown> {
  if (!body || typeof body !== "object") {
    throwAppError(ERROR_CODES.INVALID_INPUT, { details: "Body must be an object" });
  }

  const raw = body as Record<string, unknown>;

  // Type validation per field (all optional for update)
  if (raw.name !== undefined && typeof raw.name !== "string") {
    throwAppError(ERROR_CODES.INVALID_FIELD_VALUE, { field: "name" });
  }

  // Extract ONLY whitelisted fields
  return extractFields(raw, UPDATE_FIELDS);
}
```

### state-machine.ts Pattern

```typescript
import { throwAppError, ERROR_CODES } from "./errors.ts";

// === TYPES ===

export type <Module>Status = "draft" | "active" | "paused" | "completed" | "archived";

// === TRANSITION MAP (if it's not here, it's not allowed) ===

const TRANSITIONS: Record<<Module>Status, <Module>Status[]> = {
  draft: ["active"],
  active: ["paused", "completed"],
  paused: ["active", "archived"],
  completed: ["archived"],
  archived: [], // Terminal state
};

// === ROLE REQUIREMENTS PER TRANSITION ===

const TRANSITION_ROLES: Record<string, string[]> = {
  "draft->active": ["admin", "manager"],
  "active->paused": ["admin"],
  "active->completed": ["admin"],
  "paused->active": ["admin", "manager"],
  "paused->archived": ["admin"],
  "completed->archived": ["admin"],
};

// === PURE FUNCTIONS (exported for unit testing) ===

export function canTransition(from: <Module>Status, to: <Module>Status): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
}

export function getValidTransitions(from: <Module>Status): <Module>Status[] {
  return TRANSITIONS[from] || [];
}

export function validateTransition(
  from: <Module>Status,
  to: <Module>Status,
  userRole: string
): void {
  if (!canTransition(from, to)) {
    throwAppError(ERROR_CODES.INVALID_TRANSITION, {
      from,
      to,
      valid: getValidTransitions(from).join(", ") || "none",
    });
  }

  const key = `${from}->${to}`;
  const allowedRoles = TRANSITION_ROLES[key];
  if (allowedRoles && !allowedRoles.includes(userRole)) {
    throwAppError(ERROR_CODES.UNAUTHORIZED_ROLE);
  }
}

// === STATUS HELPERS ===

export function isTerminal(status: <Module>Status): boolean {
  return getValidTransitions(status).length === 0;
}

export function isActive(status: <Module>Status): boolean {
  return status === "active";
}
```

## Anti-Patterns (NEVER do these)

| Anti-Pattern | Correct Pattern | CWE |
|-------------|-----------------|-----|
| `...body` spread to INSERT/UPDATE | `extractFields(body, WHITELIST)` | CWE-915 |
| Rely only on RLS for auth | Check role in Edge Function + RLS as defense-in-depth | CWE-862 |
| `catch(e) { return new Response(400) }` for all errors | Use AppError with proper HTTP status codes | CWE-209 |
| No validation on inputs | Validate EVERY field server-side | CWE-20 |
| Multiple separate Edge Functions per module | Consolidate into single `<module>-api/` | - |
| State transitions without guards | Explicit transition map + role check | CWE-284 |
| `tenant_id` from request body | Always derive from `auth.uid()` via user_roles | CWE-639 |
| `console.log(error)` in responses | Log server-side only, return sanitized message | CWE-209 |

## Testing Requirements

Every Edge Function MUST have:
- Unit tests for ALL validators (pure functions, no DB needed)
- Unit tests for ALL error codes (correct message, status)
- Unit tests for state machine transitions (valid + invalid + roles)
- Service tests for CRUD operations (real DB)
- Service tests for auth/role enforcement (real auth)
- Service tests for tenant isolation (multi-tenant scenarios)
- Naming convention: `A-<MODULE_INITIAL>-NNN: CATEGORY: description`

## Response Format (standard)

All endpoints return:
```json
{
  "success": true|false,
  "data": { ... },       // On success
  "error": "message",    // On error (user-facing, Spanish)
  "code": "ERROR_CODE"   // On error (machine-readable)
}
```

## Integration

- **References:** WorkLife's `worklife-api/` as gold standard
- **Shared utilities:** `supabase/functions/_shared/cors.ts`, `_shared/types.ts`
- **Uses skills:** software-architecture, supabase-postgres-best-practices
- **Test helpers:** Follow worklife-api/__tests__/helpers/ patterns
