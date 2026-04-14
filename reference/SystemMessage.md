# Create a SystemMessage

Create a SystemMessage

## Usage

``` r
SystemMessage(subtype, data)
```

## Arguments

- subtype:

  Character. Subtype string.

- data:

  List. Raw data dict.

## Value

Object of class `SystemMessage`.

## Examples

``` r
msg <- SystemMessage("init", list(session_id = "abc"))
msg$subtype
#> [1] "init"
```
