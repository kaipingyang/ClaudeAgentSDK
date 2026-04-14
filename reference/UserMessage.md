# Create a UserMessage

Create a UserMessage

## Usage

``` r
UserMessage(
  content,
  uuid = NULL,
  parent_tool_use_id = NULL,
  tool_use_result = NULL
)
```

## Arguments

- content:

  Character or list of content blocks.

- uuid:

  Character or NULL. Unique message ID.

- parent_tool_use_id:

  Character or NULL.

- tool_use_result:

  List or NULL.

## Value

Object of class `UserMessage`.
