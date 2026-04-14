# Create a RateLimitEvent

Create a RateLimitEvent

## Usage

``` r
RateLimitEvent(rate_limit_info, uuid, session_id)
```

## Arguments

- rate_limit_info:

  A `RateLimitInfo` object.

- uuid:

  Character.

- session_id:

  Character.

## Value

Object of class `RateLimitEvent`.

## Examples

``` r
info <- RateLimitInfo("allowed_warning", utilization = 0.85)
evt  <- RateLimitEvent(info, uuid = "u1", session_id = "s1")
evt$rate_limit_info$status
#> [1] "allowed_warning"
```
