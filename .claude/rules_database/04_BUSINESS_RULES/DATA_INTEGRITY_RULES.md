```markdown
# DATA INTEGRITY RULES

# REFERENTIAL INTEGRITY

ALL relationships MUST:
- use FK constraints
- define ON DELETE behavior
- define ON UPDATE behavior

No implicit relationships allowed.

---

# ORPHAN PREVENTION

The schema MUST prevent:
- orphan rows
- broken references
- detached transactional records

Use:
```sql
ON DELETE CASCADE
```

when existential dependency exists.

---

# DOMAIN INTEGRITY

Domains MUST:
- restrict allowable values
- use CHECK constraints
- use reusable catalogs when appropriate

---

# UNIQUENESS RULES

Semantic uniqueness MUST be enforced using:
- UNIQUE constraints
- composite UNIQUE constraints

Avoid duplicated business meaning.

---

# CONSISTENCY RULES

The database engine MUST enforce:
- business consistency
- relationship validity
- transactional safety

Do NOT delegate integrity exclusively to application code.

---

# CHECK CONSTRAINT POLICY

Use CHECK constraints aggressively.

Examples:
```sql
quantity > 0
age >= 18
start_date <= end_date
```

---

# NULL CONTROL

NULL values MUST:
- be intentional
- be semantically justified

Avoid uncontrolled nullable columns.

---

# TRANSACTIONAL SAFETY

Transactions MUST:
- preserve consistency
- avoid partial updates
- maintain deterministic outcomes

---

# IMMUTABLE IDENTIFIERS

Primary Keys MUST:
- never mutate
- remain stable
- uniquely identify entities
```
