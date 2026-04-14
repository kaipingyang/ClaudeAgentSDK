# Create a TaskProgressMessage

Create a TaskProgressMessage

## Usage

``` r
TaskProgressMessage(
  subtype,
  data,
  task_id,
  description,
  usage,
  uuid,
  session_id,
  tool_use_id = NULL,
  last_tool_name = NULL
)
```

## Arguments

- subtype:

  Character.

- data:

  List.

- task_id:

  Character.

- description:

  Character.

- usage:

  List. Usage stats.

- uuid:

  Character.

- session_id:

  Character.

- tool_use_id:

  Character or NULL.

- last_tool_name:

  Character or NULL.

## Value

Object of class `c("TaskProgressMessage","SystemMessage")`.
