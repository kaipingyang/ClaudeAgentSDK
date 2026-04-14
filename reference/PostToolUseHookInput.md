# Create a PostToolUseHookInput

Create a PostToolUseHookInput

## Usage

``` r
PostToolUseHookInput(
  session_id,
  transcript_path,
  cwd,
  tool_name,
  tool_input,
  tool_response,
  tool_use_id,
  permission_mode = NULL,
  agent_id = NULL,
  agent_type = NULL
)
```

## Arguments

- session_id:

  Character.

- transcript_path:

  Character.

- cwd:

  Character.

- tool_name:

  Character.

- tool_input:

  List.

- tool_response:

  Any.

- tool_use_id:

  Character.

- permission_mode:

  Character or NULL.

- agent_id:

  Character or NULL.

- agent_type:

  Character or NULL.

## Value

Object of class `PostToolUseHookInput`.

## Examples

``` r
h <- PostToolUseHookInput(
  session_id = "s1", transcript_path = "/tmp/t.jsonl", cwd = "/tmp",
  tool_name = "Bash", tool_input = list(command = "ls"),
  tool_response = "file.txt\n", tool_use_id = "t1"
)
h$tool_name
#> [1] "Bash"
```
