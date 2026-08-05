# CLAUDE.md

The operating contract for this repository lives in **[AGENTS.md](AGENTS.md)**.

Read it before touching code. It is agent-agnostic on purpose — Codex, Cursor,
Windsurf and Claude Code all work from the same contract, so there is exactly one
source of truth and no chance of the two files drifting apart.

Anything Claude-Code-specific (hooks, skills, permission settings) belongs in
`.claude/`, not here.
