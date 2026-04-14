# Build a control-response JSON string

Build a control-response JSON string

## Usage

``` r
build_control_response(request_id, response)
```

## Arguments

- request_id:

  Character. The `request_id` from the incoming `control_request`.

- response:

  List. The response payload.

## Value

Character(1). JSON string to write to the CLI's stdin.
