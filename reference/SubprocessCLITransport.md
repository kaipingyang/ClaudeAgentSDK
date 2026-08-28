# SubprocessCLITransport R6 Class

Internal class (not exported). Spawns a `claude` subprocess with
`--output-format stream-json --input-format stream-json --verbose`,
reads newline-delimited JSON from stdout, and handles the bidirectional
control protocol (initialize, permission_request, hook_callback,
interrupt).

## Usage

    t <- SubprocessCLITransport$new(options)
    t$connect()
    t$send(build_user_message_json("Hello"))
    gen <- t$receive_messages()
    coro::loop(for (msg in gen) { ... })
    t$disconnect()

## Methods

### Public methods

- [`SubprocessCLITransport$new()`](#method-SubprocessCLITransport-initialize)

- [`SubprocessCLITransport$connect()`](#method-SubprocessCLITransport-connect)

- [`SubprocessCLITransport$disconnect()`](#method-SubprocessCLITransport-disconnect)

- [`SubprocessCLITransport$send()`](#method-SubprocessCLITransport-send)

- [`SubprocessCLITransport$is_alive()`](#method-SubprocessCLITransport-is_alive)

- [`SubprocessCLITransport$get_init_result()`](#method-SubprocessCLITransport-get_init_result)

- [`SubprocessCLITransport$send_async_callback()`](#method-SubprocessCLITransport-send_async_callback)

- [`SubprocessCLITransport$send_async()`](#method-SubprocessCLITransport-send_async)

- [`SubprocessCLITransport$send_and_wait()`](#method-SubprocessCLITransport-send_and_wait)

- [`SubprocessCLITransport$read_available_messages()`](#method-SubprocessCLITransport-read_available_messages)

- [`SubprocessCLITransport$get_pending_permission()`](#method-SubprocessCLITransport-get_pending_permission)

- [`SubprocessCLITransport$resolve_pending_permission()`](#method-SubprocessCLITransport-resolve_pending_permission)

- [`SubprocessCLITransport$receive_messages()`](#method-SubprocessCLITransport-receive_messages)

- [`SubprocessCLITransport$clone()`](#method-SubprocessCLITransport-clone)

------------------------------------------------------------------------

### `SubprocessCLITransport$new()`

Initialize the transport with a `ClaudeAgentOptions` object.

#### Usage

    SubprocessCLITransport$new(options)

#### Arguments

- `options`:

  A
  [`ClaudeAgentOptions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ClaudeAgentOptions.md)
  object.

------------------------------------------------------------------------

### `SubprocessCLITransport$connect()`

Start the subprocess and wait for the `initialize` control-request
handshake.

#### Usage

    SubprocessCLITransport$connect()

------------------------------------------------------------------------

### `SubprocessCLITransport$disconnect()`

Gracefully shut down the subprocess.

#### Usage

    SubprocessCLITransport$disconnect()

------------------------------------------------------------------------

### `SubprocessCLITransport$send()`

Write a JSON string to the subprocess stdin.

#### Usage

    SubprocessCLITransport$send(message_json)

#### Arguments

- `message_json`:

  Character(1). Must NOT include a trailing newline; one is appended
  automatically.

------------------------------------------------------------------------

### `SubprocessCLITransport$is_alive()`

Return TRUE if the subprocess is running.

#### Usage

    SubprocessCLITransport$is_alive()

------------------------------------------------------------------------

### `SubprocessCLITransport$get_init_result()`

Return the server initialization info captured during the initialize
handshake, or NULL if not yet connected.

#### Usage

    SubprocessCLITransport$get_init_result()

------------------------------------------------------------------------

### `SubprocessCLITransport$send_async_callback()`

Send a control request and settle callbacks from the transport's normal
stdout reader. This method creates no promise and never reads stdout.

#### Usage

    SubprocessCLITransport$send_async_callback(
      request,
      on_fulfilled,
      on_rejected,
      timeout_ms = 5000L
    )

#### Arguments

- `request`:

  List. Control request body (must have `subtype`).

- `on_fulfilled`:

  Function called with the response payload.

- `on_rejected`:

  Function called with an error condition.

- `timeout_ms`:

  Numeric. Milliseconds before asynchronous rejection; use `Inf` to
  disable the callback timer.

#### Returns

The request id invisibly.

------------------------------------------------------------------------

### `SubprocessCLITransport$send_async()`

Send a control request and return a promise settled by the transport's
normal stdout reader. This method never reads stdout.

#### Usage

    SubprocessCLITransport$send_async(request, timeout_ms = 5000L)

#### Arguments

- `request`:

  List. Control request body (must have `subtype`).

- `timeout_ms`:

  Integer. Milliseconds before asynchronous rejection.

#### Returns

A
[`promises::promise`](https://rstudio.github.io/promises/reference/promise.html)
resolving to the response payload.

------------------------------------------------------------------------

### `SubprocessCLITransport$send_and_wait()`

Send a control request and synchronously poll for its response. Buffers
any SDK messages received before the response so they are not lost from
the main receive loop.

Mirrors Python's `Query._send_control_request()` (synchronous version).
Safe to call between turns (not while `receive_messages()` is being
iterated).

#### Usage

    SubprocessCLITransport$send_and_wait(request, timeout_ms = 30000L)

#### Arguments

- `request`:

  List. Control request body (must have `subtype`).

- `timeout_ms`:

  Integer. Milliseconds to wait (default 30 000).

#### Returns

Named list with the response payload, or `NULL` on timeout.

------------------------------------------------------------------------

### `SubprocessCLITransport$read_available_messages()`

Perform a single non-blocking read cycle. Polls stdout with a 0 ms
timeout, reads any available data, parses complete JSON lines into typed
message objects, handles control requests internally, and returns a list
of SDK messages (never control messages).

Returns an empty list when no data is available — the caller can
schedule the next call via
[`later::later()`](https://later.r-lib.org/reference/later.html) for
event-loop-friendly polling.

#### Usage

    SubprocessCLITransport$read_available_messages()

#### Returns

List of typed message objects (may be empty).

------------------------------------------------------------------------

### `SubprocessCLITransport$get_pending_permission()`

Get a pending permission request by ID, or NULL.

#### Usage

    SubprocessCLITransport$get_pending_permission(request_id)

#### Arguments

- `request_id`:

  Character.

------------------------------------------------------------------------

### `SubprocessCLITransport$resolve_pending_permission()`

Resolve a pending permission request by sending the control response to
the CLI.

#### Usage

    SubprocessCLITransport$resolve_pending_permission(request_id, response)

#### Arguments

- `request_id`:

  Character.

- `response`:

  List with `behavior`, and optionally `updatedInput`, `message`,
  `interrupt`.

------------------------------------------------------------------------

### `SubprocessCLITransport$receive_messages()`

Return a `coro` generator that yields typed message objects until a
`ResultMessage` is received or the process exits. Control requests are
handled internally and never yielded.

#### Usage

    SubprocessCLITransport$receive_messages()

------------------------------------------------------------------------

### `SubprocessCLITransport$clone()`

The objects of this class are cloneable with this method.

#### Usage

    SubprocessCLITransport$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
