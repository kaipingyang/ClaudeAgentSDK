# Create a PermissionUpdate

Specifies a permission rule change to apply.

## Usage

``` r
PermissionUpdate(
  type,
  rules = NULL,
  behavior = NULL,
  mode = NULL,
  directories = NULL,
  destination = NULL
)
```

## Arguments

- type:

  Character. One of `"addRules"`, `"replaceRules"`, `"removeRules"`,
  `"setMode"`, `"addDirectories"`, `"removeDirectories"`.

- rules:

  List of `PermissionRuleValue` or NULL.

- behavior:

  Character or NULL. `"allow"`, `"deny"`, or `"ask"`.

- mode:

  Character or NULL. Permission mode.

- directories:

  Character vector or NULL.

- destination:

  Character or NULL. `"userSettings"`, `"projectSettings"`,
  `"localSettings"`, or `"session"`.

## Value

Object of class `PermissionUpdate`.
