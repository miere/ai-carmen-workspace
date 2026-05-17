# AGENTS.md — Carmen Automations

## Project Principles

### Architecture
- **Python 3** by default. Use other languages only by explicit agreement.
- **Single Responsibility Principle** — each module/class does one thing well.
- **Common Closure Principle** — classes that change for the same reason live together.

### Directory Structure
```
automations/
├── AGENTS.md          ← this file (instructions for agents)
├── libs/              ← auxiliary Python modules & classes
│   └── <domain>/      ← optional sub-folders for grouped concerns
└── <command>.py       ← entry-point scripts callable from Hermes
```

### Conventions
- Entry scripts live at root level, named after the command they expose (e.g., `slack-cli.py`).
- All reusable logic lives in `libs/` — never inline in entry scripts.
- Environment variables loaded from `.env` at the project root (`~/Development/Carmen/.env`), never hardcoded.
- Scripts use `#!/usr/bin/env python3` shebang.
- Use `argparse` for CLI argument parsing.
- Log to stderr, output results to stdout unless otherwise specified.
- Agent (brains) delegations: coordinator (Carmen) plans, Engineer agent implements, Code Reviewer agent reviews.

### Agent Delegation Pattern
When Carmen receives an implementation task:
1. **Plan** — design the structure, API surface, error handling strategy
2. **Delegate to Engineer** — pass the plan + AGENTS.md context to the Coder agent
3. **Delegate to Code Reviewer** — review the output against the plan
4. **Report** — summarise results to the user
