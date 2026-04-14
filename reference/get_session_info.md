# Get metadata for a single session

Get metadata for a single session

## Usage

``` r
get_session_info(session_id, directory = NULL)
```

## Arguments

- session_id:

  Character. UUID of the session.

- directory:

  Character or NULL. Project directory; when `NULL` all project
  directories are searched.

## Value

An `SDKSessionInfo` object, or `NULL` if not found.
