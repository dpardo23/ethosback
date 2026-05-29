```markdown
# GLOBAL NON-NEGOTIABLE RULES

## NEVER DELETE EXISTING STRUCTURES

You MUST NEVER delete:
- Tables
- Columns
- Domains
- ENUMS
- Schemas
- Views
- Functions
- Triggers
- Extensions
- Business semantics

You MAY:
- Refactor
- Normalize
- Reorganize
- Add UUIDs
- Add indexes
- Add constraints
- Add partitioning
- Add audit structures
- Improve relationships
- Improve naming consistency

---

# UUID MANDATORY POLICY

EVERY table MUST contain:

```sql
id_entity UUID PRIMARY KEY DEFAULT gen_random_uuid()
```

If UUID does not exist:
- Add UUID
- Refactor PK/FK safely
- Preserve compatibility

UUIDs are mandatory.

---

# FOREIGN KEY SEMANTICS

Foreign Keys MUST:
- Use semantic role naming
- Reflect relationship meaning

GOOD:
- id_manager
- id_creator
- id_reviewer

BAD:
- id_user

All FK constraints MUST define:
- ON DELETE
- ON UPDATE

Rules:
- Composition → CASCADE
- Master-Detail → CASCADE
- Catalogs → RESTRICT
- Reflexive → SET NULL or CASCADE

---

# NAMING CONVENTIONS

## Tables
- singular
- snake_case
- lowercase

## Prefixes
- catalog_
- rel_
- hist_
- audit_
- mv_
- vw_

## Constraints
- pk_
- fk_
- uq_
- chk_
- idx_

---

# ACID COMPLIANCE

The architecture MUST enforce:
- Atomicity
- Consistency
- Isolation
- Durability

Prevent:
- orphan records
- inconsistent states
- denormalized corruption

Constraints are mandatory.
```
