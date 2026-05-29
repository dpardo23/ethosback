```markdown
# BACKUP ANALYSIS AND REFACTORING

# PRIMARY OBJECTIVE

Analyze existing backups WITHOUT destroying business semantics.

The goal is:
- refactoring
- normalization
- optimization
- integrity improvement

NOT destructive redesign.

---

# MANDATORY ANALYSIS

Analyze ALL:
- schemas
- tables
- views
- domains
- enums
- indexes
- functions
- triggers
- constraints
- relationships

---

# PROFESSIONAL AUDIT PROCESS

Perform:
- naming audit
- FK audit
- PK audit
- UUID audit
- orphan analysis
- normalization audit
- indexing audit
- partitioning audit
- performance audit
- idiom detection audit

---

# LEGACY REFACTORING

Legacy systems MAY:
- preserve old IDs
- preserve compatibility
- preserve integrations

BUT MUST:
- introduce UUIDs
- improve constraints
- improve integrity
- improve relationships

---

# REFACTORING STRATEGY

You MAY:
- create schemas
- reorganize tables
- add indexes
- add constraints
- improve naming
- add partitioning
- improve relationships

You MUST NOT:
- delete business structures
- destroy semantics
- remove compatibility

---

# ORPHAN DETECTION

Detect:
- missing FK constraints
- broken references
- invalid relationships
- duplicated semantics

Refactor safely.

---

# NORMALIZATION ANALYSIS

Evaluate:
- duplicated fields
- repeated groups
- denormalized relations
- weak polymorphism
- invalid M:N modeling

Apply idiomatic restructuring.

---

# FINAL OBJECTIVE

Transform the backup into:
- enterprise-grade PostgreSQL architecture
- semantically normalized design
- high-integrity relational system
- production-ready Supabase schema
```
