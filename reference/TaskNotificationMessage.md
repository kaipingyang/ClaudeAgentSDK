# Create a TaskNotificationMessage

Create a TaskNotificationMessage

## Usage

``` r
TaskNotificationMessage(
  subtype,
  data,
  task_id,
  status,
  output_file,
  summary,
  uuid,
  session_id,
  tool_use_id = NULL,
  usage = NULL
)
```

## Arguments

- subtype:

  Character.

- data:

  List.

- task_id:

  Character.

- status:

  Character. `"completed"`, `"failed"`, or `"stopped"`.

- output_file:

  Character.

- summary:

  Character.

- uuid:

  Character.

- session_id:

  Character.

- tool_use_id:

  Character or NULL.

- usage:

  List or NULL.

## Value

Object of class `c("TaskNotificationMessage","SystemMessage")`.
