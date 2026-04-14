# Create a StreamEvent

Create a StreamEvent

## Usage

``` r
StreamEvent(uuid, session_id, event, parent_tool_use_id = NULL)
```

## Arguments

- uuid:

  Character.

- session_id:

  Character.

- event:

  List. Raw Anthropic API stream event.

- parent_tool_use_id:

  Character or NULL.

## Value

Object of class `StreamEvent`.
