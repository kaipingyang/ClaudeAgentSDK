# Throw a Claude SDK error

Throw a Claude SDK error

## Usage

``` r
claude_error(message, class, ...)
```

## Arguments

- message:

  Character. Human-readable error message.

- class:

  Character vector. Additional S3 subclasses prepended before
  `"claude_error"`.

- ...:

  Additional fields stored in the condition object (passed to
  [`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html)).
