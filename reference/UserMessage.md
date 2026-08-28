# Create a UserMessage

Create a UserMessage

## Usage

``` r
UserMessage(
  content,
  uuid = NULL,
  parent_tool_use_id = NULL,
  tool_use_result = NULL,
  is_replay = NULL
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

- is_replay:

  Logical or NULL. Whether the CLI marked this as a replayed message.

## Value

Object of class `UserMessage`.

## Examples

``` r
msg <- UserMessage("Hello, Claude!")
msg$content
#> [1] "Hello, Claude!"
```
