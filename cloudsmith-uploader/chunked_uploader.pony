use "files"
use http_client = "http_client"
use "net"

class val ChunkUploadError
  """
  A chunk upload failure with a diagnostic message.
  """
  let message: String

  new val create(message': String) =>
    message = message'

type ChunkUploadResult is (None | ChunkUploadError val)

actor ChunkedUploader is http_client.HTTPClientConnectionActor
  """
  Reads a file in fixed-size chunks and PUTs each one
  sequentially over a single reused HTTPS connection.
  """
  var _http: http_client.HTTPClientConnection =
    http_client.HTTPClientConnection.none()
  let _cb: {(ChunkUploadResult)} val
  let _host: String
  let _api_key: String
  let _upload_path: String
  let _identifier: String
  let _file: File
  let _chunk_size: USize
  var _part_number: USize = 1
  var _collector: http_client.ResponseCollector =
    http_client.ResponseCollector
  var _last_status: U16 = 0
  let _request_timeout_ms: U64
  var _timer: (TimerToken | None) = None
  var _done: Bool = false

  new create(
    auth: TCPConnectAuth,
    ssl_ctx: SSLContext val,
    host: String val,
    port: String val,
    upload_path: String val,
    identifier: String val,
    api_key: String val,
    file_auth: FileAuth,
    file_path_str: String val,
    cb: {(ChunkUploadResult)} val,
    chunk_size: USize = 104_857_600,
    connect_timeout_ms: U64 = 30_000,
    request_timeout_ms: U64 = 600_000)
  =>
    _cb = cb
    _host = host
    _api_key = api_key
    _upload_path = upload_path
    _identifier = identifier
    _chunk_size = chunk_size
    _request_timeout_ms = request_timeout_ms
    _file =
      File.open(FilePath(file_auth, file_path_str))
    if not (_file.errno() is FileOK) then
      _done = true
      _cb(
        ChunkUploadError(
          "failed to open file: " + file_path_str))
      return
    end
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
          max_body_size' = 1_048_576,
          connection_timeout' = conn_timeout))

  fun ref _http_client_connection()
    : http_client.HTTPClientConnection
  =>
    _http

  fun ref on_connected() =>
    """
    Starts the chunk upload sequence.
    """
    _send_next_chunk()

  fun ref _send_next_chunk() =>
    let chunk: Array[U8] val = _file.read(_chunk_size)
    if chunk.size() == 0 then
      _done = true
      _file.dispose()
      _cb(None)
      _http.close()
      return
    end
    if not (_file.errno() is FileOK) then
      _done = true
      _file.dispose()
      _cb(
        ChunkUploadError(
          "I/O error reading chunk " +
            _part_number.string()))
      _http.close()
      return
    end
    let sep: String val =
      if _upload_path.contains("?") then "&"
      else "?"
      end
    let path: String iso =
      _upload_path + sep + "upload_id=" + _identifier +
        "&part_number=" + _part_number.string()
    let req = http_client.Request.put(
      consume path)
      .header("X-Api-Key", _api_key)
      .body(chunk)
      .build()
    _http.send_request(req)
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
    Delivers a ChunkUploadError with the failure reason.
    """
    if _done then return end
    _done = true
    _file.dispose()
    _cb(
      ChunkUploadError(
        "chunk upload connection to " + _host +
          " failed: " +
          _FailureReasonString(reason)))

  fun ref on_parse_error(
    err: http_client.ParseError)
  =>
    """
    Delivers a parse error and closes the connection.
    """
    if _done then return end
    match _timer
    | let t: TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    _done = true
    _file.dispose()
    _cb(
      ChunkUploadError(
        "chunk upload: HTTP parse error from " +
          _host))
    _http.close()

  fun ref on_response(
    response: http_client.Response val)
  =>
    """
    Captures the status and starts a new collector.
    """
    _last_status = response.status
    _collector = http_client.ResponseCollector
    _collector.set_response(response)

  fun ref on_body_chunk(data: Array[U8] val) =>
    """
    Appends data to the response collector.
    """
    _collector.add_chunk(data)

  fun ref on_response_complete() =>
    """
    Sends the next chunk on 2xx, or fails on other statuses.
    """
    if _done then return end
    match _timer
    | let t: TimerToken =>
      _http.cancel_timer(t)
      _timer = None
    end
    if (_last_status < 200) or
      (_last_status >= 300)
    then
      _done = true
      _file.dispose()
      let body_str =
        try
          let r = _collector.build()?
          String.from_array(r.body)
        else
          ""
        end
      _cb(
        ChunkUploadError(
          "chunk " + _part_number.string() +
            " upload failed: " +
            _last_status.string() +
            " " + body_str))
      _http.close()
      return
    end
    _part_number = _part_number + 1
    _send_next_chunk()

  fun ref on_timer(token: TimerToken) =>
    """
    Fails the upload if the token matches the active timer.
    """
    match _timer
    | let t: TimerToken if t == token =>
      _timer = None
      if _done then return end
      _done = true
      _file.dispose()
      _cb(
        ChunkUploadError(
          "chunk " + _part_number.string() +
            " upload timed out"))
      _http.close()
    end

  fun ref on_timer_failure() =>
    """
    Delivers an error when the timer cannot be armed.
    """
    if _done then return end
    _done = true
    _file.dispose()
    _cb(
      ChunkUploadError(
        "failed to arm timeout timer for chunk " +
          "upload to " + _host))
    _http.close()
