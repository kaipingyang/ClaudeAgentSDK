# Result of a fork_session() operation

Result of a fork_session() operation

## Usage

``` r
ForkSessionResult(session_id)
```

## Arguments

- session_id:

  Character. UUID of the new forked session.

## Value

Object of class `ForkSessionResult`.

## Examples

``` r
res <- ForkSessionResult(session_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
res$session_id
#> [1] "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
```
