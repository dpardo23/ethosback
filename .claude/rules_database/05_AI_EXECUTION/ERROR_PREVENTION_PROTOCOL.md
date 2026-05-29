```markdown
# ERROR PREVENTION PROTOCOL

# PRIMARY OBJECTIVE

Minimize architectural errors toward 0%.

---

# MANDATORY VALIDATION

Before final delivery validate:
- PK integrity
- FK integrity
- UUID consistency
- cascade behavior
- naming consistency
- normalization level
- partitioning opportunities
- index coverage
- Supabase compatibility

---

# FORBIDDEN PATTERNS

FORBIDDEN:
- weak polymorphism
- missing FK indexes
- uncontrolled nullable columns
- duplicated semantics
- denormalized M:N arrays
- missing UUIDs
- missing constraints
- orphan-prone relationships

---

# SAFETY RULES

NEVER:
- delete business semantics
- destroy legacy compatibility
- generate unsafe cascades
- omit FK constraints

---

# SQL SAFETY

Generated SQL MUST:
- execute deterministically
- support rollback safety
- preserve integrity
- avoid dependency conflicts

---

# PERFORMANCE SAFETY

Avoid:
- unnecessary sequential scans
- recursive bottlenecks
- missing indexes
- excessive trigger logic

---

# CONSISTENCY SAFETY

All naming MUST remain:
- semantic
- deterministic
- standardized

---

# FINAL VALIDATION

The final architecture MUST:
- look enterprise-grade
- remain production-safe
- preserve semantic correctness
- remain fully normalized
```
