# Create a PermissionRequestHookInput

Create a PermissionRequestHookInput

## Usage

``` r
PermissionRequestHookInput(
  session_id,
  transcript_path,
  cwd,
  tool_name,
  tool_input,
  permission_suggestions = NULL,
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

- permission_suggestions:

  List or NULL.

- permission_mode:

  Character or NULL.

- agent_id:

  Character or NULL.

- agent_type:

  Character or NULL.

## Value

Object of class `PermissionRequestHookInput`.
