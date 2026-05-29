```markdown
# POSTGRESQL PERFORMANCE ENGINEERING

# PERFORMANCE PHILOSOPHY

The database MUST optimize:
- transactional consistency
- relational navigation
- query predictability
- index efficiency
- scalability
- planner optimization

---

# INDEXING STRATEGIES

Mandatory indexes:
- PK indexes
- FK indexes
- UNIQUE indexes
- search indexes
- temporal indexes

---

# INDEX TYPES

## BTREE
Use for:
- equality
- ranges
- ordering

## GIN
Use for:
- JSONB
- full-text search
- arrays when unavoidable

## BRIN
Use for:
- massive temporal datasets
- append-only logs

## HASH
Use ONLY when justified.

---

# COVERING INDEXES

Use INCLUDE columns for:
- covering queries
- reducing heap reads

---

# PARTIAL INDEXES

Use partial indexes when:
- filtering by status
- filtering active records
- sparse indexing improves performance

---

# MATERIALIZED VIEWS

Use materialized views for:
- heavy reports
- analytical aggregation
- expensive joins

Refresh strategically.

---

# QUERY OPTIMIZATION

Avoid:
- SELECT *
- missing WHERE indexes
- unnecessary recursion
- Cartesian joins

Prefer:
- explicit columns
- indexed predicates
- optimized joins
- deterministic filtering

---

# VACUUM STRATEGY

Large transactional systems MUST consider:
- VACUUM
- AUTOVACUUM tuning
- ANALYZE
- bloat prevention

---

# TRANSACTION OPTIMIZATION

Avoid:
- long-running transactions
- excessive locking
- deadlock risks

Use:
- small deterministic transactions
- indexed updates
- optimistic concurrency when applicable

---

# PLANNER AWARENESS

The architecture MUST consider:
- execution plans
- sequential scans
- index scans
- bitmap scans
- join strategies

Indexes MUST support planner efficiency.
```
