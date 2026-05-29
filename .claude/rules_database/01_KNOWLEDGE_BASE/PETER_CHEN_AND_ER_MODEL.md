```markdown
# PETER CHEN ENTITY-RELATIONSHIP THEORY

## Core Concept

The real world consists of:
- Entities
- Relationships between entities

The database MUST represent semantic reality.

---

# ENTITY THEORY

An Entity:
- is uniquely identifiable
- represents real-world semantics

An Entity Set:
- groups semantically related entities

---

# ATTRIBUTE THEORY

Attributes are mathematical functions mapping:
- Entity Sets
- Relationship Sets
to Value Sets.

Attributes are NOT simple fields.

Domains MUST be enforced through:
- types
- CHECK constraints
- FK constraints

---

# RELATIONSHIP THEORY

Relationships are semantic associations between entities.

Relationship roles MUST define FK names semantically.

---

# CARDINALITY

Supported:
- 1:1
- 1:N
- M:N

All M:N relationships MUST become explicit relational structures.

---

# WEAK ENTITIES

Weak entities:
- depend existentially on parent entities
- MUST use ON DELETE CASCADE

---

# IMPEDANCE MISMATCH

Object identity is volatile.

Relational identity MUST be protected through:
- PK
- FK
- constraints
- UUIDs

The database engine governs integrity, not the application.
```
