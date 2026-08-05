# Create a TaskBudget

API-side task budget in tokens. When set, the model is made aware of its
remaining token budget so it can pace tool use and wrap up before the
limit.

## Usage

``` r
TaskBudget(total)
```

## Arguments

- total:

  Integer. Maximum token budget for the task.

## Value

Object of class `TaskBudget`.

## Examples

``` r
budget <- TaskBudget(total = 10000L)
budget$total
#> [1] 10000
```
