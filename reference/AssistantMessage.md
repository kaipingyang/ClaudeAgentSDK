# Create an AssistantMessage

Create an AssistantMessage

## Usage

``` r
AssistantMessage(
  content,
  model,
  parent_tool_use_id = NULL,
  error = NULL,
  usage = NULL,
  message_id = NULL,
  stop_reason = NULL,
  session_id = NULL,
  uuid = NULL
)
```

## Arguments

- content:

  List of content blocks.

- model:

  Character. Model ID.

- parent_tool_use_id:

  Character or NULL.

- error:

  Character or NULL. Error type if present.

- usage:

  List or NULL. Token usage dict.

- message_id:

  Character or NULL.

- stop_reason:

  Character or NULL.

- session_id:

  Character or NULL.

- uuid:

  Character or NULL.

## Value

Object of class `AssistantMessage`.
