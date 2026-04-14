# Create a HookMatcher

Pairs a tool/event matcher with a list of hook callback functions.
Mirrors Python's `HookMatcher` dataclass in `types.py`.

## Usage

``` r
HookMatcher(matcher, hooks, timeout = NULL)
```

## Arguments

- matcher:

  Character or NULL. Tool name or pattern to match (e.g., `"Bash"`,
  `"Write"`). Pass `NULL` to match all events.

- hooks:

  List of functions. Each function has signature
  `function(input_data, tool_use_id, context)` and returns a named list.

- timeout:

  Integer or NULL. Timeout in milliseconds for each hook call.

## Value

Object of class `HookMatcher`.
