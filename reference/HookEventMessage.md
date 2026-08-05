# Create a HookEventMessage

Hook event emitted by the CLI when `include_hook_events` is enabled. The
CLI emits hook lifecycle events (PreToolUse, PostToolUse, Stop, etc.)
into the message stream as
`{"type":"system","subtype":"hook_started"|"hook_response", "hook_event":"PreToolUse", ...}`.

## Usage

``` r
HookEventMessage(
  subtype,
  hook_event_name,
  data,
  session_id = NULL,
  uuid = NULL
)
```

## Arguments

- subtype:

  Character. `"hook_started"` or `"hook_response"`.

- hook_event_name:

  Character. The hook event name (e.g. `"PreToolUse"`).

- data:

  List. The raw message payload.

- session_id:

  Character or NULL.

- uuid:

  Character or NULL.

## Value

Object of class `HookEventMessage` (subclass of `SystemMessage`).

## Examples

``` r
msg <- HookEventMessage(
  subtype = "hook_started", hook_event_name = "PreToolUse",
  data = list(), session_id = "s1", uuid = "u1"
)
msg$hook_event_name
#> [1] "PreToolUse"
```
