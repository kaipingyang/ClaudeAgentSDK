# Create a SandboxIgnoreViolations

Create a SandboxIgnoreViolations

## Usage

``` r
SandboxIgnoreViolations(file = NULL, network = NULL)
```

## Arguments

- file:

  Character vector or NULL.

- network:

  Character vector or NULL.

## Value

Object of class `SandboxIgnoreViolations`.

## Examples

``` r
ig <- SandboxIgnoreViolations(file = c("/tmp/ok.txt"))
ig$file
#> [1] "/tmp/ok.txt"
```
