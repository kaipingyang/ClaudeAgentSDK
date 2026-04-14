# Create a PermissionRuleValue

Create a PermissionRuleValue

## Usage

``` r
PermissionRuleValue(tool_name, rule_content = NULL)
```

## Arguments

- tool_name:

  Character. Tool name pattern.

- rule_content:

  Character or NULL.

## Value

Object of class `PermissionRuleValue`.

## Examples

``` r
rv <- PermissionRuleValue("Bash", rule_content = "allow")
rv$tool_name
#> [1] "Bash"
```
