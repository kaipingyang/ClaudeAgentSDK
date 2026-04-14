# Create a SandboxNetworkConfig

Create a SandboxNetworkConfig

## Usage

``` r
SandboxNetworkConfig(
  allow_unix_sockets = NULL,
  allow_all_unix_sockets = NULL,
  allow_local_binding = NULL,
  http_proxy_port = NULL,
  socks_proxy_port = NULL
)
```

## Arguments

- allow_unix_sockets:

  Character vector or NULL.

- allow_all_unix_sockets:

  Logical or NULL.

- allow_local_binding:

  Logical or NULL.

- http_proxy_port:

  Integer or NULL.

- socks_proxy_port:

  Integer or NULL.

## Value

Object of class `SandboxNetworkConfig`.

## Examples

``` r
nc <- SandboxNetworkConfig(allow_local_binding = TRUE)
nc$allowLocalBinding
#> [1] TRUE
```
