use http_client = "http_client"
use "net"

primitive _FailureReasonString
  fun apply(reason: ConnectionFailureReason): String =>
    match \exhaustive\ reason
    | ConnectionFailedDNS => "DNS resolution failed"
    | ConnectionFailedTCP => "TCP connection failed"
    | ConnectionFailedSSL => "SSL handshake failed"
    | ConnectionFailedTimeout =>
      "connection timed out"
    | ConnectionFailedTimerError =>
      "connect timer failed"
    end

class val APIError
  """
  An error from an API request — connection failure, parse error,
  timeout, or response assembly failure.
  """
  let message: String

  new val create(message': String) =>
    message = message'

type APIResult is
  (http_client.HTTPResponse val | APIError val)

actor APIConnection is http_client.HTTPClientConnectionActor
  """
  Single-request HTTPS actor. Connects, sends one pre-built
  request, collects the response, and delivers it via callback.
  """
  var _http: http_client.HTTPClientConnection =
    http_client.HTTPClientConnection.none()
  let _cb: {(APIResult)} val
  let _host: String
  let _request: http_client.HTTPRequest val
  var _collector: http_client.ResponseCollector =
    http_client.ResponseCollector
  let _request_timeout_ms: U64
  var _timer: (TimerToken | None) = None
  var _delivered: Bool = false

  new create(
    auth: TCPConnectAuth,
    ssl_ctx: SSLContext val,
    host: String val,
    port: String val,
    request: http_client.HTTPRequest val,
    cb: {(APIResult)} val,
    connect_timeout_ms: U64 = 30_000,
    request_timeout_ms: U64 = 120_000,
    max_body_size: USize = 10_485_760)
  =>
    _cb = cb
    _host = host
    _request = request
    _request_timeout_ms = request_timeout_ms
    let conn_timeout: (ConnectionTimeout | None) =
      match MakeConnectionTimeout(connect_timeout_ms)
      | let t: ConnectionTimeout => t
      else None
      end
    _http =
      http_client.HTTPClientConnection.ssl(
        auth,
        ssl_ctx,
        host,
        port,
        this,
        http_client.ClientConnectionConfig(where
          max_body_size' = max_body_size,
          connection_timeout' = conn_timeout))

  fun ref _http_client_connection()
    : http_client.HTTPClientConnection
  =>
    _http

  fun ref on_connected() =>
    """
    Sends the request and arms the timeout.
    """
    _http.send_request(_request)
    match MakeTimerDuration(_request_timeout_ms)
    | let d: TimerDuration =>
      match _http.set_timer(d)
      | let t: TimerToken => _timer = t
      end
    end

  fun ref on_connection_failure(
    reason: ConnectionFailureReason)
  =>
    """
    Delivers an APIError with the failure reason.
    """
    if _delivered then return end
    _delivered = true
    _cb(
      APIError(
        "connection to " + _host +
          " failed: " +
          _FailureReasonString(reason)))

  fun ref on_parse_error(
    err: http_client.ParseError)
  =>
    """
    Delivers an APIError for the parse failure, cancels
    the request timer, and closes the connection.
    """
    if _delivered then return end
    _delivered = true
    match _timer
    | let t: TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    let err_str =
      match \exhaustive\ err
      | http_client.TooLarge => "response too large"
      | http_client.InvalidStatusLine =>
        "invalid status line"
      | http_client.InvalidVersion =>
        "invalid HTTP version"
      | http_client.MalformedHeaders =>
        "malformed headers"
      | http_client.InvalidContentLength =>
        "invalid content-length"
      | http_client.InvalidChunk =>
        "invalid chunk encoding"
      | http_client.BodyTooLarge => "body too large"
      end
    _cb(
      APIError(
        "HTTP parse error from " + _host +
          ": " + err_str))
    _http.close()

  fun ref on_response(
    response: http_client.Response val)
  =>
    """
    Starts a new response collector for this response.
    """
    _collector = http_client.ResponseCollector
    _collector.set_response(response)

  fun ref on_body_chunk(data: Array[U8] val) =>
    """
    Appends data to the response collector.
    """
    _collector.add_chunk(data)

  fun ref on_response_complete() =>
    """
    Assembles the collected response and delivers it.
    """
    if _delivered then return end
    _delivered = true
    match _timer
    | let t: TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    try
      let response = _collector.build()?
      _cb(response)
    else
      _cb(APIError("failed to build response"))
    end
    _http.close()

  fun ref on_timer(token: TimerToken) =>
    """
    Delivers a timeout error if the token matches.
    """
    if _delivered then return end
    match _timer
    | let t: TimerToken if t == token =>
      _delivered = true
      _timer = None
      _cb(
        APIError(
          "request to " + _host + " timed out"))
      _http.close()
    end

  fun ref on_timer_failure() =>
    """
    Delivers an error when the timer cannot be armed.
    """
    if _delivered then return end
    _delivered = true
    _cb(
      APIError(
        "failed to arm timeout timer for " +
          _host))
    _http.close()
