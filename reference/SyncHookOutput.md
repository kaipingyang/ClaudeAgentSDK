# Create a SyncHookOutput

Synchronous hook output returned by hook callbacks.

## Usage

``` r
SyncHookOutput(
  continue_ = NULL,
  suppress_output = NULL,
  stop_reason = NULL,
  decision = NULL,
  system_message = NULL,
  reason = NULL,
  hook_specific_output = NULL
)
```

## Arguments

- continue\_:

  Logical or NULL. Whether to continue execution. Note: The trailing
  underscore avoids R's `continue` reserved word. Serialized as
  `"continue"` for the CLI.

- suppress_output:

  Logical or NULL. Suppress output.

- stop_reason:

  Character or NULL.

- decision:

  Character or NULL. `"block"` to block execution.

- system_message:

  Character or NULL.

- reason:

  Character or NULL.

- hook_specific_output:

  List or NULL.

## Value

Object of class `SyncHookOutput`.
