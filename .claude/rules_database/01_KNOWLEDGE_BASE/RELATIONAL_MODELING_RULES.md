```markdown
# RELATIONAL MODELING RULES

## SEMANTIC-FIRST MODELING

The database MUST be modeled from semantic reality first.

Always think in this order:
1. Real-world entities
2. Relationships
3. Relationship semantics
4. Cardinalities
5. Constraints
6. Relational translation
7. Performance optimization

NEVER design starting from tables alone.

---

# RELATIONSHIP MODELING

## 1:N RELATIONSHIPS

All 1:N relationships MUST:
- place the FK in the N-side
- use explicit FK constraints
- define ON DELETE behavior
- define ON UPDATE behavior

---

## M:N RELATIONSHIPS

ALL M:N relationships MUST:
- become explicit composition entities
- NEVER use JSONB arrays
- NEVER use array columns
- NEVER simulate relations

Composition entities MUST:
- contain UUID PK
- support metadata
- support auditability
- support history tracking

---

# RELATIONSHIP ATTRIBUTES

Attributes belonging to a relationship:
- MUST exist ONLY in relationship tables
- MUST NEVER exist in parent entities

Examples:
- assigned_at
- quantity
- score
- participation_percentage
- approval_status

---

# WEAK ENTITY RULES

Weak entities:
- depend existentially on parent entities
- MUST use CASCADE deletion
- MUST enforce FK integrity

---

# IDENTITY MODELING

Relational identity MUST be:
- immutable
- deterministic
- globally unique

Preferred strategy:
```sql
UUID PRIMARY KEY DEFAULT gen_random_uuid()
```

---

# DOMAIN MODELING

Domains MUST:
- enforce semantic restrictions
- use CHECK constraints
- use FK references when reusable
- avoid uncontrolled VARCHAR usage

---

# NULLABILITY RULES

NULL is ONLY allowed when:
- semantically valid
- optional by business definition

Avoid nullable abuse.

---

# DERIVED DATA RULES

Avoid storing:
- calculated fields
- duplicated semantics
- redundant aggregates

Prefer:
- views
- materialized views
- runtime calculations

unless performance requires controlled denormalization.
```
