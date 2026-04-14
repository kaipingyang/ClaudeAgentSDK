# Check Claude Code CLI version

Runs `claude -v`, parses the semantic version, and warns if it is below
the minimum required version. Matches the Python SDK's
`_check_claude_version()` logic.

## Usage

``` r
check_claude_version(cli_path, min_version = MINIMUM_CLAUDE_CODE_VERSION)
```

## Arguments

- cli_path:

  Character. Path to the `claude` binary.

- min_version:

  Character. Minimum acceptable version string (default `"2.0.0"`).

## Value

Invisibly returns the detected version string, or `NULL` on failure.
