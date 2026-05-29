```markdown
# SQL GENERATION RULES

# OUTPUT REQUIREMENTS

Generated SQL MUST be:
- deterministic
- ordered
- executable
- production-ready
- fully commented

---

# SQL STRUCTURE ORDER

1. BEGIN;
2. Extensions
3. Schemas
4. Domains
5. ENUMS
6. Catalog tables
7. Base entities
8. Weak entities
9. Composition entities
10. Reflexive entities
11. Junction tables
12. Constraints
13. Indexes
14. Partitioning
15. Views
16. Materialized views
17. Triggers
18. Audit structures
19. Seed data
20. Functions
21. Procedures
22. Comments
23. COMMIT;

---

# TABLE GENERATION

Each table MUST:
- define UUID PK
- define constraints
- define FK actions
- define indexes
- define comments

---

# COMMENTING RULES

Every:
- table
- column
- index
- FK
- trigger
- function
- partition

MUST contain comments.

---

# CONSTRAINT RULES

Constraints are mandatory:
- PK
- FK
- UNIQUE
- CHECK

Use aggressive relational integrity enforcement.

---

# TRANSACTIONAL SAFETY

DDL MUST remain:
- deterministic
- consistent
- rollback-safe

Prefer transactional migrations whenever possible.

---

# MIGRATION SAFETY

Schema migrations MUST:
- preserve data
- preserve compatibility
- avoid destructive operations
- maintain referential integrity
```
