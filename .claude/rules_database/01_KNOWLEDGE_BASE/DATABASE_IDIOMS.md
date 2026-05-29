```markdown
# DATABASE IDIOMS

ALL schemas MUST use idiomatic relational modeling.

---

# CLASSIFIER-CATALOG

Reusable domains MUST become catalog tables.

Rules:
- UUID PK
- UNIQUE description
- RESTRICT deletes

Example:
- statuses
- categories
- priorities

---

# COMPOSITION

ALL M:N relationships:
- MUST become explicit composition tables
- MUST support metadata
- MUST support auditing
- MUST support history

Composition tables MUST:
- use UUID
- use CASCADE
- use UNIQUE combined constraints

---

# MASTER-DETAIL

Transactional entities:
- invoice
- order
- receipt
- transaction

MUST use:
- master table
- detail table

Details:
- depend existentially
- MUST cascade deletes

---

# SIMPLE REFLEXIVE

Hierarchies MUST use:
- self-referencing FK
- recursive-safe modeling

---

# COMPOUND REFLEXIVE

Graph structures MUST use:
- associative reflexive tables
- dual FK references

Prevent cycles:
```sql
CHECK (id_parent != id_child)
```

---

# IS-A SPECIALIZATION

Inheritance MUST use:
- supertype/subtype

FORBIDDEN:
- entity_type polymorphism

MANDATORY:
- shared PK/FK inheritance
```
