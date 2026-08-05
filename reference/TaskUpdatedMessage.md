# Create a TaskUpdatedMessage

System message emitted as `system`/`task_updated` while a task moves
through its lifecycle. Terminal completion sometimes arrives *only* as a
`task_updated` patch (with no accompanying `TaskNotificationMessage`),
so this is surfaced as a typed lifecycle message. Parsed defensively:
the patch may omit `uuid`/`session_id`/`status`.

## Usage

``` r
TaskUpdatedMessage(
  subtype,
  data,
  task_id,
  patch,
  status = NULL,
  session_id = NULL,
  uuid = NULL
)
```

## Arguments

- subtype:

  Character. Always `"task_updated"`.

- data:

  List. The raw message payload.

- task_id:

  Character. Task ID (may be empty string if absent).

- patch:

  List. The full patch dict from the CLI.

- status:

  Character or NULL. Task status, taken from `patch$status`.

- session_id:

  Character or NULL.

- uuid:

  Character or NULL.

## Value

Object of class `TaskUpdatedMessage` (subclass of `SystemMessage`).

## Examples

``` r
msg <- TaskUpdatedMessage(
  subtype = "task_updated", data = list(),
  task_id = "t1", patch = list(status = "completed"),
  status = "completed", session_id = "s1", uuid = "u1"
)
msg$status
#> [1] "completed"
```
