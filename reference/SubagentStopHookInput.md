# Create a SubagentStopHookInput

Create a SubagentStopHookInput

## Usage

``` r
SubagentStopHookInput(
  session_id,
  transcript_path,
  cwd,
  stop_hook_active,
  agent_id,
  agent_transcript_path,
  agent_type,
  permission_mode = NULL
)
```

## Arguments

- session_id:

  Character.

- transcript_path:

  Character.

- cwd:

  Character.

- stop_hook_active:

  Logical.

- agent_id:

  Character.

- agent_transcript_path:

  Character.

- agent_type:

  Character.

- permission_mode:

  Character or NULL.

## Value

Object of class `SubagentStopHookInput`.

## Examples

``` r
h <- SubagentStopHookInput(
  session_id = "s1", transcript_path = "/tmp/t.jsonl", cwd = "/tmp",
  stop_hook_active = FALSE, agent_id = "a1",
  agent_transcript_path = "/tmp/a.jsonl", agent_type = "subagent"
)
h$agent_type
#> [1] "subagent"
```
