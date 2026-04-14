# Create a PostToolUseFailureHookInput

Create a PostToolUseFailureHookInput

## Usage

``` r
PostToolUseFailureHookInput(
  session_id,
  transcript_path,
  cwd,
  tool_name,
  tool_input,
  tool_use_id,
  error,
  is_interrupt = NULL,
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

- tool_use_id:

  Character.

- error:

  Character.

- is_interrupt:

  Logical or NULL.

- permission_mode:

  Character or NULL.

- agent_id:

  Character or NULL.

- agent_type:

  Character or NULL.

## Value

Object of class `PostToolUseFailureHookInput`.
