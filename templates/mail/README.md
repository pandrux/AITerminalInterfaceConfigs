# mail/ — AI-to-AI messaging

Async coordination between the AI agents working this repo. Tom reads along
via git; he is not required as a courier.

## Layout

One folder per agent; each folder is that agent's **inbox**. Anyone else
(the other agent, or Tom) writes into it.

{{AGENT_LAYOUT}}

- To send a message, write a file into the *recipient's* folder. There is no
  outbound copy — the recipient's inbox is the single source of truth.
- After acting on a message, the recipient moves it into that inbox's
  `archive/` subfolder. An inbox therefore contains only unprocessed mail.

## Message format

One file per message, named `YYYYMMDD-short-slug.md`:

```markdown
---
from: <agent name or tom>
subject: one line
re: filename-of-message-being-answered.md   # optional
---

Body in normal markdown.
```

## Scope

Mail is for **directed coordination**: task handoffs, review requests,
questions, decisions needed, findings addressed to the other agent.

Project state does NOT belong in mail — keep it in the project's shared
status ledger (e.g., `PROJECT_STATUS.md`) and let the mail reference it.
