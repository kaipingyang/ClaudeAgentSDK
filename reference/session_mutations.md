# Session Mutation Functions

Rename, tag, delete, and fork Claude Code sessions stored under
`~/.claude/projects/`. Appends typed metadata entries to JSONL files
(matching the CLI pattern). Mirrors `_internal/session_mutations.py`
from the Python SDK.

**Concurrent writers**: if the target session is currently open in a CLI
process, the CLI will absorb SDK-written entries on its next metadata
re-read (tail-scan window). Safe to call from any SDK host process.
