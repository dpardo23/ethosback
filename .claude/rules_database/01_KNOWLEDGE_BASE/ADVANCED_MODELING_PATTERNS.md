```markdown
# ADVANCED MODELING PATTERNS

# TEMPORAL MODELING

Historical state changes MUST NEVER overwrite important history.

Use:
- valid_from
- valid_to
- history tables
- audit entities

Apply:
- Slowly Changing Dimension Type 2 (SCD Type 2)

---

# EVENT MODELING

Business events MUST become:
- transactional entities
- composition entities
- historical entities

Examples:
- status changes
- approvals
- assignments
- transactions
- audits

---

# CLOSURE TABLE PATTERN

Deep hierarchical structures MUST evaluate:
- closure tables

Avoid excessive recursive reads.

Closure tables MUST:
- maintain ancestor relationships
- maintain descendant relationships
- support recursive optimization

---

# SOFT DELETE STRATEGY

Soft delete MUST use:
```sql
deleted_at TIMESTAMPTZ NULL
```

Never use:
```sql
is_deleted BOOLEAN
```

---

# AUDIT TRAIL MODELING

Critical entities MUST support:
- created_at
- updated_at
- deleted_at
- created_by
- updated_by

Auditability is mandatory for enterprise systems.

---

# MULTI-TENANT MODELING

When applicable:
- isolate tenant ownership
- index tenant identifiers
- secure tenant boundaries

---

# ANALYTICAL READ MODELS

Heavy analytical queries SHOULD use:
- materialized views
- denormalized read models
- aggregated reporting structures

Transactional integrity MUST remain normalized.

---

# POLYMORPHIC AVOIDANCE

FORBIDDEN:
```sql
entity_id
entity_type
```

MANDATORY:
- proper IS-A modeling
- supertype/subtype structures
- explicit FK inheritance

---

# RECURSIVE STRUCTURE RULES

Recursive structures MUST:
- prevent cycles
- support recursive traversal
- support optimized indexing

Mandatory protection:
```sql
CHECK (id_parent != id_child)
```
```
