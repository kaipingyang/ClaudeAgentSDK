# Create a SubagentStartHookInput

Create a SubagentStartHookInput

## Usage

``` r
SubagentStartHookInput(
  session_id,
  transcript_path,
  cwd,
  agent_id,
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

- agent_id:

  Character.

- agent_type:

  Character.

- permission_mode:

  Character or NULL.

## Value

Object of class `SubagentStartHookInput`.

## Examples

``` r
h <- SubagentStartHookInput(
  session_id = "s1", transcript_path = "/tmp/t.jsonl", cwd = "/tmp",
  agent_id = "a1", agent_type = "subagent"
)
h$agent_id
#> [1] "a1"
```
