# Create SandboxSettings

Create SandboxSettings

## Usage

``` r
SandboxSettings(
  enabled = NULL,
  auto_allow_bash_if_sandboxed = NULL,
  excluded_commands = NULL,
  allow_unsandboxed_commands = NULL,
  network = NULL,
  ignore_violations = NULL,
  enable_weaker_nested_sandbox = NULL
)
```

## Arguments

- enabled:

  Logical or NULL.

- auto_allow_bash_if_sandboxed:

  Logical or NULL.

- excluded_commands:

  Character vector or NULL.

- allow_unsandboxed_commands:

  Logical or NULL.

- network:

  `SandboxNetworkConfig` or NULL.

- ignore_violations:

  `SandboxIgnoreViolations` or NULL.

- enable_weaker_nested_sandbox:

  Logical or NULL.

## Value

Object of class `SandboxSettings`.

## Examples

``` r
sb <- SandboxSettings(enabled = TRUE, allow_unsandboxed_commands = FALSE)
sb$enabled
#> [1] TRUE
```
