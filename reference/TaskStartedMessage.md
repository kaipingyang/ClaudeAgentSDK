# Create a TaskStartedMessage

Create a TaskStartedMessage

## Usage

``` r
TaskStartedMessage(
  subtype,
  data,
  task_id,
  description,
  uuid,
  session_id,
  tool_use_id = NULL,
  task_type = NULL
)
```

## Arguments

- subtype:

  Character.

- data:

  List. Raw data.

- task_id:

  Character.

- description:

  Character.

- uuid:

  Character.

- session_id:

  Character.

- tool_use_id:

  Character or NULL.

- task_type:

  Character or NULL.

## Value

Object of class `c("TaskStartedMessage","SystemMessage")`.

## Examples

``` r
msg <- TaskStartedMessage(
  subtype = "task_started", data = list(),
  task_id = "t1", description = "Run tests",
  uuid = "u1", session_id = "s1"
)
msg$task_id
#> [1] "t1"
```
