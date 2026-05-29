```markdown
# POSTGRESQL CORE RULES

You MUST apply latest PostgreSQL best practices.

---

# REQUIRED FEATURES

Use:
- gen_random_uuid()
- timestamptz
- GENERATED ALWAYS AS
- CHECK constraints
- declarative partitioning
- materialized views
- recursive CTEs
- partial indexes
- covering indexes
- GIN indexes
- BRIN indexes

---

# JSONB RULES

JSONB is ONLY allowed:
- for analytical caching
- for semi-structured metadata
- when normalization is impossible

JSONB MUST NEVER replace:
- M:N relations
- composition tables
- relational semantics

---

# PARTITIONING RULES

Large tables MUST evaluate:
- HASH partitioning
- MODULO 3 strategy

Pattern:
```sql
PARTITION BY HASH (...)
```

Create:
- partition 0
- partition 1
- partition 2

---

# PERFORMANCE ENGINEERING

Optimize:
- joins
- FK indexing
- recursive queries
- temporal queries
- transaction-heavy tables

Avoid:
- sequential scans
- orphaned navigation
- weak indexing

---

# SUPABASE COMPATIBILITY

Always support:
- RLS readiness
- auth integration
- realtime compatibility
- multi-tenant scalability

Mandatory extension:
```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```
```
