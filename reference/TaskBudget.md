# Create a TaskBudget

API-side task budget in tokens. When set, the model is made aware of its
remaining token budget so it can pace tool use and wrap up before the
limit.

## Usage

``` r
TaskBudget(max_tokens)
```

## Arguments

- max_tokens:

  Integer. Maximum token budget for the task.

## Value

Object of class `TaskBudget`.
