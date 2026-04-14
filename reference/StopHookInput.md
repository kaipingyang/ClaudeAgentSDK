# Create a StopHookInput

Create a StopHookInput

## Usage

``` r
StopHookInput(
  session_id,
  transcript_path,
  cwd,
  stop_hook_active,
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

- permission_mode:

  Character or NULL.

## Value

Object of class `StopHookInput`.

## Examples

``` r
h <- StopHookInput(
  session_id = "s1", transcript_path = "/tmp/t.jsonl",
  cwd = "/tmp", stop_hook_active = FALSE
)
h$stop_hook_active
#> [1] FALSE
```
