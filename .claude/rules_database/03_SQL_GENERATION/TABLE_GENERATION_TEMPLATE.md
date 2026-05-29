```markdown
# TABLE GENERATION TEMPLATE

Every generated table MUST follow:

```sql
CREATE TABLE schema.entity (
    id_entity UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Business columns

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NULL,
    deleted_at TIMESTAMPTZ NULL
);

-- Foreign Keys

-- Constraints

-- Unique Constraints

-- Check Constraints

-- Indexes

-- Partitioning

-- Comments

-- Triggers

-- Audit structures
```

---

# REQUIRED CONSTRAINTS

Use:
- PRIMARY KEY
- FOREIGN KEY
- UNIQUE
- CHECK

Aggressively.

---

# REQUIRED INDEXING

Create indexes for:
- FKs
- timestamps
- searches
- compositions
- recursive structures

---

# COMMENTING

Every structure MUST contain:
- semantic explanation
- business explanation
- relational explanation
```
