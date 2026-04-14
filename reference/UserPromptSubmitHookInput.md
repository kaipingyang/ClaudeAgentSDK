# Create a UserPromptSubmitHookInput

Create a UserPromptSubmitHookInput

## Usage

``` r
UserPromptSubmitHookInput(
  session_id,
  transcript_path,
  cwd,
  prompt,
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

- prompt:

  Character.

- permission_mode:

  Character or NULL.

## Value

Object of class `UserPromptSubmitHookInput`.

## Examples

``` r
h <- UserPromptSubmitHookInput(
  session_id = "s1", transcript_path = "/tmp/t.jsonl",
  cwd = "/tmp", prompt = "Hello!"
)
h$prompt
#> [1] "Hello!"
```
