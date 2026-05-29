```markdown
# FUNCTIONS AND PROCEDURES RULES

# PLACEMENT RULE

ALL functions and procedures MUST be placed:
- at the END of the SQL script

---

# FUNCTION DESIGN

Functions MUST:
- be deterministic when possible
- remain transactional
- avoid hidden side effects
- contain documentation comments

---

# STORED PROCEDURES

Procedures MAY:
- orchestrate business workflows
- execute transactional operations
- support batch processing

Procedures MUST:
- validate integrity
- handle errors safely
- preserve ACID guarantees

---

# TRIGGER RULES

Triggers MUST:
- remain lightweight
- avoid hidden recursion
- avoid performance bottlenecks

Use triggers ONLY when justified.

---

# AUDIT FUNCTIONS

Audit systems SHOULD use:
- reusable trigger functions
- generic auditing logic
- timestamp tracking

---

# SECURITY DEFINER

Use SECURITY DEFINER ONLY:
- when strictly necessary
- with controlled permissions

Avoid privilege escalation risks.

---

# RPC SUPPORT

Functions SHOULD support:
- Supabase RPC patterns
- deterministic API behavior
- transactional consistency

---

# ERROR HANDLING

Functions MUST:
- validate inputs
- prevent inconsistent states
- provide deterministic behavior

Avoid silent failures.
```
