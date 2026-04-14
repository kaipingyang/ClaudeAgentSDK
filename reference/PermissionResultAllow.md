# Allow permission result

Allow permission result

## Usage

``` r
PermissionResultAllow(updated_input = NULL, updated_permissions = NULL)
```

## Arguments

- updated_input:

  List or NULL. Modified tool input.

- updated_permissions:

  List or NULL. Permission updates.

## Value

Object of class `PermissionResultAllow`.

## Examples

``` r
# Allow with default input
result <- PermissionResultAllow()
result$behavior  # "allow"
#> [1] "allow"

# Use in a can_use_tool callback
opts <- ClaudeAgentOptions(
  can_use_tool = function(name, input, ctx) PermissionResultAllow()
)
```
