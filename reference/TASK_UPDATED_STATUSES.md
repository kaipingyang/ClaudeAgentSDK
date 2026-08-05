# Possible status values reported inside a `task_updated` patch

A task moves through these states; `completed` and `failed`/`killed` are
terminal. Note `task_updated` reports the raw `killed` status.

## Usage

``` r
TASK_UPDATED_STATUSES
```
