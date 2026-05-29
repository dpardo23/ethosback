```markdown
# INDEX AND PARTITIONING RULES

# INDEXING REQUIREMENTS

Mandatory indexes:
- PK indexes
- FK indexes
- UNIQUE indexes
- timestamp indexes
- recursive structure indexes

---

# FK INDEX POLICY

ALL Foreign Keys MUST be indexed.

This is mandatory.

---

# TEMPORAL INDEXING

Tables containing:
- created_at
- updated_at
- valid_from
- valid_to

MUST evaluate:
- BTREE indexes
- BRIN indexes

---

# PARTITIONING STRATEGY

Large tables MUST evaluate:
- HASH partitioning
- RANGE partitioning
- temporal partitioning

Preferred strategy:
```sql
PARTITION BY HASH (...)
```

with modulo 3.

---

# REQUIRED PARTITIONS

Create:
- partition_0
- partition_1
- partition_2

---

# PARTITIONING CANDIDATES

Evaluate partitioning for:
- audit tables
- history tables
- transactional logs
- event tables
- high-volume compositions

---

# INDEX NAMING

Use:
- idx_table_column
- uq_table_columns
- fk_table_reference

---

# RECURSIVE STRUCTURE INDEXES

Recursive structures MUST index:
- parent identifiers
- closure relationships
- ancestor lookups

---

# COVERING INDEXES

Use INCLUDE when:
- avoiding heap fetches
- optimizing read-heavy queries

---

# ANALYTICAL OPTIMIZATION

Analytical models MAY use:
- materialized views
- denormalized reporting structures

Transactional entities MUST remain normalized.
```
