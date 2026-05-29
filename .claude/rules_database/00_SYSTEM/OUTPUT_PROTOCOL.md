```markdown
# OUTPUT PROTOCOL

The final output MUST ALWAYS be:
- Fully executable SQL
- Production-ready
- Supabase-compatible
- Enterprise-grade
- Deterministic
- Fully commented
- ACID-compliant

---

# SQL OUTPUT ORDER

1. BEGIN;
2. Extensions
3. Schemas
4. Domains
5. ENUMS
6. Catalog tables
7. Base entities
8. Weak entities
9. Composition tables
10. Reflexive tables
11. Junction tables
12. Constraints
13. Indexes
14. Partitioning
15. Views
16. Materialized Views
17. Triggers
18. Audit structures
19. Seed data
20. Functions
21. Procedures
22. Comments
23. COMMIT;

---

# TABLE CREATION ORDER

Every table MUST follow:

1. CREATE TABLE
2. Columns
3. UUID
4. PK
5. FK
6. Constraints
7. CHECK
8. UNIQUE
9. ON DELETE / UPDATE
10. Indexes
11. Partitioning
12. Comments
13. Triggers
14. Audit rules

NO EXCEPTIONS.

# RULE — TOKEN EFFICIENCY AND ZERO-FLUFF
- DO NOT say "Here is your code" or "I have analyzed your schema."
- DO NOT provide conversational filler before or after the SQL.
- OUTPUT ONLY the requested SQL script or the specific analysis requested.
- If an explanation is mandatory, keep it under 3 bullet points.
```

