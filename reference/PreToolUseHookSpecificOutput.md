# Hook-specific output for PreToolUse hook

Hook-specific output for PreToolUse hook

## Usage

``` r
PreToolUseHookSpecificOutput(
  permission_decision = NULL,
  permission_decision_reason = NULL,
  updated_input = NULL,
  additional_context = NULL
)
```

## Arguments

- permission_decision:

  Character or NULL. One of `"allow"`, `"deny"`, `"ask"`.

- permission_decision_reason:

  Character or NULL.

- updated_input:

  List or NULL. Modified tool input.

- additional_context:

  Character or NULL.

## Value

Object of class `PreToolUseHookSpecificOutput`.
