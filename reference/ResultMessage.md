# Create a ResultMessage

Create a ResultMessage

## Usage

``` r
ResultMessage(
  subtype,
  duration_ms,
  duration_api_ms,
  is_error,
  num_turns,
  session_id,
  stop_reason = NULL,
  total_cost_usd = NULL,
  usage = NULL,
  result = NULL,
  structured_output = NULL,
  model_usage = NULL,
  permission_denials = NULL,
  errors = NULL,
  uuid = NULL
)
```

## Arguments

- subtype:

  Character.

- duration_ms:

  Integer.

- duration_api_ms:

  Integer.

- is_error:

  Logical.

- num_turns:

  Integer.

- session_id:

  Character.

- stop_reason:

  Character or NULL.

- total_cost_usd:

  Numeric or NULL.

- usage:

  List or NULL.

- result:

  Character or NULL.

- structured_output:

  Any or NULL.

- model_usage:

  List or NULL.

- permission_denials:

  List or NULL.

- errors:

  List or NULL.

- uuid:

  Character or NULL.

## Value

Object of class `ResultMessage`.
