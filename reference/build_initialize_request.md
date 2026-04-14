# Build an initialize control-request JSON string

Build an initialize control-request JSON string

## Usage

``` r
build_initialize_request(
  request_id,
  hooks_config = NULL,
  agents = NULL,
  exclude_dynamic_sections = NULL
)
```

## Arguments

- request_id:

  Character.

- hooks_config:

  List or NULL. Hook configuration.

- agents:

  List or NULL. Agent definitions.

- exclude_dynamic_sections:

  Logical or NULL.
