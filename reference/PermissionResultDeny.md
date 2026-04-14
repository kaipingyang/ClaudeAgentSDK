# Deny permission result

Deny permission result

## Usage

``` r
PermissionResultDeny(message = "", interrupt = FALSE)
```

## Arguments

- message:

  Character. Reason for denial.

- interrupt:

  Logical. Whether to interrupt the current operation.

## Value

Object of class `PermissionResultDeny`.

## Examples

``` r
result <- PermissionResultDeny("Not allowed in this context.")
result$behavior  # "deny"
#> [1] "deny"
result$message
#> [1] "Not allowed in this context."
```
