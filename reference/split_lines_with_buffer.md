# Split buffered output into complete lines

Appends `new_output` to the existing `buf` and splits on newlines.
Returns completed lines and any remaining partial line.

## Usage

``` r
split_lines_with_buffer(buf, new_output)
```

## Arguments

- buf:

  Character(1). Current carry-over buffer (may be empty string).

- new_output:

  Character(1). Raw bytes / text just read from the process.

## Value

Named list with:

- `complete_lines` — Character vector of fully terminated lines (newline
  stripped).

- `remaining` — Character(1) with any trailing partial line.
