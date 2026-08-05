# Create a DeferredToolUse

Tool use that was deferred by a PreToolUse hook returning `"defer"`.
When a PreToolUse hook returns `permissionDecision: "defer"`, the run
stops and the result message carries the deferred tool call here so the
caller can inspect it and decide whether to resume.

## Usage

``` r
DeferredToolUse(id, name, input)
```

## Arguments

- id:

  Character. Tool use ID.

- name:

  Character. Tool name.

- input:

  List. Tool input parameters.

## Value

Object of class `DeferredToolUse`.

## Examples

``` r
d <- DeferredToolUse("tool1", "Bash", list(command = "ls"))
d$name
#> [1] "Bash"
```
