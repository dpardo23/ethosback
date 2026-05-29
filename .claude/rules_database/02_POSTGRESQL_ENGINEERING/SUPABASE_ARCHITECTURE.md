```markdown
# SUPABASE ARCHITECTURE RULES

# SUPABASE COMPATIBILITY

All generated SQL MUST be fully compatible with:
- Supabase
- latest PostgreSQL stable version

---

# REQUIRED EXTENSIONS

Mandatory:
```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

Optional when justified:
- pg_trgm
- btree_gin
- uuid-ossp

---

# AUTH INTEGRATION

The schema MUST support:
- auth.users integration
- secure FK references
- ownership tracking

Use:
```sql
id_user UUID REFERENCES auth.users(id)
```

when appropriate.

---

# ROW LEVEL SECURITY (RLS)

The architecture MUST be RLS-ready.

Design:
- ownership boundaries
- tenant boundaries
- secure access patterns

Avoid:
- insecure global reads
- weak ownership semantics

---

# REALTIME COMPATIBILITY

Realtime-sensitive tables MUST:
- contain deterministic PKs
- use timestamps
- support lightweight updates

Avoid excessive payload columns.

---

# STORAGE INTEGRATION

File metadata MUST:
- remain relational
- support ownership
- support auditing

Avoid storing raw file binaries in relational tables.

---

# EDGE FUNCTION SUPPORT

Database structures MUST:
- support RPC calls
- support deterministic API responses
- support transactional consistency

---

# MULTI-TENANT STRATEGY

When multi-tenant:
- isolate tenant data
- index tenant_id
- secure tenant boundaries through RLS

---

# SUPABASE PERFORMANCE

Optimize:
- realtime subscriptions
- RLS filtering
- FK navigation
- auth-based queries

Avoid:
- heavy recursive subscriptions
- unindexed ownership filters
```
