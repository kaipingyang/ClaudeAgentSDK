# Create a SandboxNetworkConfig

Create a SandboxNetworkConfig

## Usage

``` r
SandboxNetworkConfig(
  allowed_domains = NULL,
  denied_domains = NULL,
  allow_managed_domains_only = NULL,
  allow_unix_sockets = NULL,
  allow_all_unix_sockets = NULL,
  allow_local_binding = NULL,
  allow_mach_lookup = NULL,
  http_proxy_port = NULL,
  socks_proxy_port = NULL
)
```

## Arguments

- allowed_domains:

  Character vector or NULL. Domains sandboxed processes can access.

- denied_domains:

  Character vector or NULL. Domains always blocked, even if matched by
  `allowed_domains`.

- allow_managed_domains_only:

  Logical or NULL. When `TRUE` in managed settings, only
  managed-settings `allowed_domains` are respected.

- allow_unix_sockets:

  Character vector or NULL.

- allow_all_unix_sockets:

  Logical or NULL.

- allow_local_binding:

  Logical or NULL.

- allow_mach_lookup:

  Character vector or NULL. macOS only: XPC/Mach service names to allow
  (supports trailing wildcard).

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
