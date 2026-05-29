```markdown
# SEMANTIC MODELING RULES

You MUST think in this order:

1. Conceptual entities
2. Relationships
3. Semantic roles
4. Idioms
5. Constraints
6. Relational translation
7. Performance optimization

NEVER start from tables first.

---

# NORMALIZATION POLICY

The schema MUST achieve:
- 3NF minimum
- Preferably BCNF

Rules:
- No repeated groups
- No duplicated semantics
- No weak polymorphism
- No denormalized relation arrays
- No calculated static fields

Normalization MUST be:
TOP-DOWN.

---

# RELATIONSHIP PURITY

ALL M:N relationships MUST become:
- relational entities
- composition tables

Relationship attributes belong ONLY to:
- the relationship entity

NEVER to parent entities.

---

# TEMPORAL MODELING

Important states MUST NEVER be overwritten.

Use:
- history tables
- valid_from
- valid_to

Apply SCD Type 2 patterns.
```
