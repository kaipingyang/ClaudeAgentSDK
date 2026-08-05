# Create a ServerToolUseBlock

Server-side tool use block (e.g. advisor, web_search, web_fetch). These
are tools the API executes server-side on the model's behalf, so they
appear in the message stream alongside regular `tool_use` blocks but the
caller never needs to return a result. `name` is a discriminator —
branch on it to know which server tool was invoked.

## Usage

``` r
ServerToolUseBlock(id, name, input)
```

## Arguments

- id:

  Character. Tool use ID.

- name:

  Character. Server tool name (one of `SERVER_TOOL_NAMES`).

- input:

  List. Tool input parameters.

## Value

Object of class `ServerToolUseBlock`.

## Examples

``` r
blk <- ServerToolUseBlock("srv1", "web_search", list(query = "R language"))
blk$name
#> [1] "web_search"
```
