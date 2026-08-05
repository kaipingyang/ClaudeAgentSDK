# Context passed to can_use_tool callbacks

Carries per-call context for tool-permission decisions.

## Usage

``` r
ToolPermissionContext(
  suggestions = list(),
  tool_use_id = NULL,
  agent_id = NULL,
  signal = NULL,
  blocked_path = NULL,
  decision_reason = NULL,
  title = NULL,
  display_name = NULL,
  description = NULL
)
```

## Arguments

- suggestions:

  List of `PermissionUpdate` objects from the CLI.

- tool_use_id:

  Character or NULL. Unique ID for this tool call.

- agent_id:

  Character or NULL. Sub-agent ID if running in an agent.

- signal:

  NULL (reserved for future abort-signal support).

- blocked_path:

  Character or NULL. File path that triggered the permission request, if
  applicable.

- decision_reason:

  Character or NULL. Explains why this permission request was triggered
  (e.g. a PreToolUse hook's `permissionDecisionReason`).

- title:

  Character or NULL. Full permission prompt sentence (e.g. "Claude wants
  to read foo.txt"). Prefer this as primary prompt text.

- display_name:

  Character or NULL. Short noun phrase for the tool action (e.g. "Read
  file"), suitable for button labels.

- description:

  Character or NULL. Human-readable subtitle for the permission UI.

## Value

Object of class `ToolPermissionContext`.
