# Create a RateLimitInfo

Create a RateLimitInfo

## Usage

``` r
RateLimitInfo(
  status,
  resets_at = NULL,
  rate_limit_type = NULL,
  utilization = NULL,
  overage_status = NULL,
  overage_resets_at = NULL,
  overage_disabled_reason = NULL,
  raw = list()
)
```

## Arguments

- status:

  Character. `"allowed"`, `"allowed_warning"`, or `"rejected"`.

- resets_at:

  Integer or NULL. Unix timestamp (ms) when limit resets.

- rate_limit_type:

  Character or NULL.

- utilization:

  Numeric or NULL. Fraction consumed (0-1).

- overage_status:

  Character or NULL.

- overage_resets_at:

  Integer or NULL.

- overage_disabled_reason:

  Character or NULL.

- raw:

  List. Full raw dict from CLI.

## Value

Object of class `RateLimitInfo`.

## Examples

``` r
info <- RateLimitInfo("allowed", utilization = 0.4)
info$status
#> [1] "allowed"
```
