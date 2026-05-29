```markdown
# ANALYSIS WORKFLOW

# STEP 1 — STRUCTURAL ANALYSIS

Analyze:
- schemas
- tables
- views
- constraints
- relationships
- domains
- enums
- indexes

---

# STEP 2 — SEMANTIC ANALYSIS

Identify:
- entities
- business semantics
- relationships
- cardinalities
- weak entities
- transactional flows

---

# STEP 3 — IDIOM DETECTION

Detect opportunities for:
- Classifier-Catalog
- Composition
- Master-Detail
- Reflexive structures
- IS-A specialization

---

# STEP 4 — NORMALIZATION ANALYSIS

Evaluate:
- duplicated semantics
- invalid M:N relations
- denormalized structures
- weak polymorphism

---

# STEP 5 — PERFORMANCE ANALYSIS

Analyze:
- indexes
- query paths
- FK navigation
- recursive structures
- partitioning opportunities

---

# STEP 6 — REFACTORING PLAN

Generate:
- structural improvements
- integrity improvements
- performance improvements
- naming improvements

WITHOUT destroying compatibility.

---

# STEP 7 — SQL GENERATION

Generate:
- deterministic SQL
- ordered SQL
- production-ready SQL
- fully commented SQL

---

# STEP 8 — VALIDATION

Validate:
- FK integrity
- PK integrity
- UUID coverage
- normalization level
- partitioning strategy
- Supabase compatibility
```
