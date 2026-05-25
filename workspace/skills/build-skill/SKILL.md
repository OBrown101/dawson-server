---
name: skill-builder
description: Create a new reusable skill for DAWSON when asked to automate workflows, encode repeatable procedures, standardize task execution, or teach DAWSON a new capability. You (DAWSON) can also create a new skill after completing a complex task, if you feel it will make you more efficient next time you need to perform the task. Triggers include "make a skill", "create a workflow", "teach yourself how to", "build a reusable process", or "add a new capability".
---

# Skill Builder

Create reusable, focused skills that help DAWSON execute recurring workflows consistently and efficiently.

A skill should:
- Solve a specific class of tasks
- Be reusable across projects
- Provide structured execution guidance
- Improve consistency and efficiency
- Reduce repeated reasoning and token usage

Skills are operational procedures, not general documentation.

---

# Skill Goals

A good skill should:

- Be narrowly scoped
- Have clear triggers for when to use it
- Provide a repeatable workflow
- Optimize for efficiency
- Avoid unnecessary depth
- Produce consistent outcomes

The skill should help DAWSON quickly orient itself and execute effectively.

---

# Skill Folder Structure

Each skill lives in:

```text
~/DAWSON/workspace/skills/<skill-name>/
```

Each skill folder must contain:

```text
SKILL.md
```

The folder name should:
- Use lowercase
- Use hyphen-separated words
- Be short and descriptive

Examples:
- `project-review`
- `bug-investigation`
- `swift-refactor`
- `api-design`

---

# Required Frontmatter

Every skill must begin with YAML frontmatter:

```yaml
---
name: skill-name
description: Short description with trigger phrases and usage guidance.
---
```

---

# Writing the Description

The description is critical because it is used for lightweight skill discovery.

The description should:
- Explain what the skill does
- Include trigger phrases
- Mention common user requests
- Clarify when the skill should be used

Descriptions should be concise but information-dense.

---

# Good Trigger Examples

Include natural trigger phrases such as:

- "review this project"
- "analyze this repository"
- "investigate this bug"
- "optimize performance"
- "refactor this code"
- "build an API"
- "write tests"
- "design a schema"

The goal is to help DAWSON recognize when the skill is relevant.

---

# Skill Structure

Use structured sections with clear headings.

Recommended structure:

1. Purpose
2. When to Use
3. Core Workflow
4. Step-by-Step Process
5. Efficiency Rules
6. Output Format
7. Examples
8. Final Principles

Skills should be easy to scan quickly.

---

# Scope Rules

A skill should focus on ONE operational area.

Good:
- Reviewing projects
- Investigating bugs
- Writing migrations
- Designing APIs
- Refactoring modules

Bad:
- "Everything about backend engineering"
- "General coding assistant"
- Massive multi-domain procedures

Large workflows should be split into multiple smaller skills.

---

# Efficiency Principles

Skills should minimize:
- Token usage
- File reads
- Redundant analysis
- Excessive depth

Encourage:
- Sampling representative files
- Working top-down
- Using summaries first
- Deferring deep dives until necessary

Skills are meant to accelerate execution, not create exhaustive reports.

---

# Writing Style

Use:
- Direct instructions
- Action-oriented language
- Clear formatting
- Concise explanations

Avoid:
- Long prose
- Philosophy
- Excessive background context
- Ambiguous guidance

Optimize for operational clarity.

---

# Output Expectations

A skill should clearly define:
- What information to gather
- What decisions to make
- What outputs to generate
- When to stop investigating

The user should receive practical, actionable results.

---

# Example Workflow Pattern

A strong workflow usually follows:

1. Understand the request
2. Gather minimal required context
3. Identify key structures/components
4. Perform focused analysis
5. Generate concise actionable output
6. Suggest optional deeper investigation

This pattern keeps execution fast and scalable.

---

# Validation Checklist

Before finalizing a skill, verify:

- The scope is narrow and reusable
- The description contains triggers
- The workflow is structured
- The instructions are operational
- The process is efficient
- The skill avoids unnecessary depth
- The formatting is clean and scannable

---

# Final Principle

A skill should function like a reusable operational playbook.

The goal is not to encode everything about a topic.

The goal is to help DAWSON reliably execute a recurring workflow quickly, consistently, and efficiently.
