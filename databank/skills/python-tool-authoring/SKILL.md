---
name: python-tool-authoring
description: Write, run, debug, and promote custom Python tools using run_python_code and run_python_script when built-in tools can't solve the task efficiently. Use when asked to "write a script", "automate this", "process/parse/convert these files", "analyze this data", perform batch operations, do repetitive computation, or whenever a task would take many manual steps that a short Python program could do in one. Also covers discovering existing tools (list_python_tools), requesting missing packages (install_python_package), and saving proven tools to the shared library (promote_python_tool).
---

# Authoring Python Tools

Solve problems by writing Python and executing it in DAWSON's sandbox. Quick snippets run via `run_python_code`; reusable modules run via `run_python_script`. Proven tools can be promoted to the shared library so every agent benefits in the future.

## When to Use

Write Python when:
- The task involves processing many files or large amounts of data
- Built-in tools would require many repetitive calls to accomplish it
- The task needs computation, parsing, transformation, or format conversion
- Precision matters (exact arithmetic, exact string manipulation, checksums)
- The same operation may be needed again later

Do **not** write Python when:
- An existing library tool already solves it (check first — see below)
- A single built-in tool call already solves the task
- The task is conversational, creative, or judgment-based

---

## Execution Model — Know the Walls

Every Python execution runs in an OS-level sandbox. These are hard limits, not suggestions; code that crosses them fails with `PermissionError`, `FileNotFoundError`, `MemoryError`, or a network error. Do not retry blocked operations — redesign around them.

| Rule | Consequence |
|---|---|
| Filesystem = workspace only | Read/write only inside this chat's workspace directories (plus read-only access to the shared `python-scripts` library and installed packages) |
| No network | `requests`, `urllib`, sockets, etc. all fail. Ask the user for data as files |
| No pip inside scripts | `pip install` fails. Use `install_python_package` instead (see below) |
| Fresh process per call | Nothing persists in memory between calls. Persist state to workspace files |
| No subprocess escape | Shelling out to system binaries is blocked or useless; do the work in Python |
| Wall-clock timeout | Default 60s. Pass `timeout_seconds` (up to the stated max) for long work |
| Memory cap | Very large allocations raise `MemoryError`. Stream/chunk big data instead of loading it whole |

---

## Choosing the Right Execution Tool

**`run_python_code`** — quick, throwaway work. Pass raw code; it runs top-to-bottom as a script; use `print()` for output. Use it to inspect a file's structure, test an approach, do a one-off calculation, or check whether a package is installed (`import x` and see). Snippets are saved into the workspace's `scratch/` folder, so a snippet that grows up can be refined into a module.

**`run_python_script`** — real tools. Write a module into the workspace, then call a specific function in it. The function is called with **keyword arguments only**:

```python
result = your_function(**args)
```

Therefore:
- Parameter names must exactly match the keys in `args`
- All argument values must be JSON-serializable (str, int, float, bool, list, dict, None)
- Return JSON-serializable values; anything else is converted with `repr()`
- Pass **paths** to large data, never the data itself — read files inside the function

Good entry point:

```python
def summarize_csv(input_path, output_path, max_rows=None):
    """Summarize a CSV file; writes a report and returns key stats."""
    ...
    return {"rows": count, "columns": cols, "report": output_path}
```

---

## Authoring Workflow

1. **Call `list_python_tools` first.** The shared library holds tools built in previous conversations, importable by module name. If one fits, use it via `run_python_script` — do not rewrite existing capability.
2. **Explore with `run_python_code`** if you need to understand the data before designing the tool (peek at file structure, count things, test a parsing approach).
3. **Write the module** into the workspace with your file tools (e.g. `workspace/csv_summarizer.py`). Subdirectories work: `workspace/tools/parsers.py` is importable as `tools.parsers`.
4. **Run it** with `run_python_script`, passing `module`, `function`, and `args`.
5. **Read the traceback on failure.** Full tracebacks come back in the error field. Fix the file and rerun — every call runs the current code on disk, never a cached version.
6. **Verify the output** (read the produced files or check the returned values) before telling the user the task is done.
7. **Persist state to files** when work spans multiple calls: JSON for small state, SQLite for structured data, plain files for artifacts. Keep throwaway intermediates in `scratch/`.

For long-running work, write progress and results to a workspace file and return promptly; check the file in a follow-up call rather than holding one call open.

Keep printed output small — print summaries, not raw data. Oversized output is truncated.

---

## Missing Packages

If an import fails because a third-party package isn't installed:

1. First try to accomplish the task with the standard library or already-installed packages — many tasks don't actually need the heavyweight dependency.
2. If the package is genuinely needed, call `install_python_package` with the package spec and a one-sentence reason. **The user must approve.** Do not ask for packages speculatively or in bulk.
3. Installs are wheels-only by default. If the install fails because no pre-built wheel exists for this platform, and the package is reputable, retry with `allow_source_build: true`.
4. Once installed, the package is available immediately and in all future conversations — never request an already-installed package again (an `ImportError` is the test).

---

## Promoting Tools to the Shared Library

A tool that solved this task well may be worth keeping for the whole kingdom. Use `promote_python_tool` when the tool is:

- **Tested** — it ran successfully on real inputs in this conversation
- **General** — parameterized, not hardcoded to this task's specific paths or values
- **Self-documenting** — module docstring plus docstrings on every public function; these become the tool's catalog entry, which is all future agents see before deciding to use it
- **Self-contained** — standard library or installed packages only; no reliance on files that exist only in this workspace

Before promoting, refactor out hardcoded paths into parameters. Promotion automatically updates the tool catalog and records the tool in shared memory — no follow-up bookkeeping is needed. If you overwrite an existing tool, the previous version is archived, not destroyed.

Do not promote one-off scripts, scratch snippets as-is, or anything the user hasn't seen working.

---

## Example Session

User asks: "Find every TODO comment across the source files in my project and give me a report."

1. `list_python_tools` → no existing tool fits
2. `run_python_code` → quick snippet to see what file types are in the project root
3. Write `workspace/todo_scanner.py` with `scan(root_path, extensions=None, output_path=None)`
4. `run_python_script` → `{"module": "todo_scanner", "function": "scan", "args": {"root_path": "/workspace/project", "output_path": "/workspace/todo_report.md"}}`
5. Traceback: forgot to skip binary files → fix, rerun
6. Verify `todo_report.md` looks right, present results
7. Tool is general-purpose and proven → `promote_python_tool` with a clear description (catalog and memory update automatically)

---

## Final Principle

**Write the smallest tool that solves the problem, prove it works, then decide if it deserves to outlive the conversation.** The sandbox walls are fixed — design within them from the start rather than discovering them by trial and error.
