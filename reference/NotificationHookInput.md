# Create a NotificationHookInput

Create a NotificationHookInput

## Usage

``` r
NotificationHookInput(
  session_id,
  transcript_path,
  cwd,
  message,
  notification_type,
  title = NULL,
  permission_mode = NULL
)
```

## Arguments

- session_id:

  Character.

- transcript_path:

  Character.

- cwd:

  Character.

- message:

  Character.

- notification_type:

  Character.

- title:

  Character or NULL.

- permission_mode:

  Character or NULL.

## Value

Object of class `NotificationHookInput`.

## Examples

``` r
h <- NotificationHookInput(
  session_id = "s1", transcript_path = "/tmp/t.jsonl", cwd = "/tmp",
  message = "Build finished.", notification_type = "info"
)
h$message
#> [1] "Build finished."
```
