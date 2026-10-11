use "files"
use http_client = "http_client"
use "net"
use "time"

actor Uploader
  """
  Orchestrates the upload as a sequence of async API calls
  with retry and exponential backoff.
  """
  let _env: Env
  let _tcp_auth: TCPConnectAuth
  let _ssl_ctx: SSLContext val
  let _file_auth: FileAuth
  let _api_host: String = "api.cloudsmith.io"
  let _api_port: String = "443"
  let _api_key: String
  let _owner: String
  let _repo: String
  let _version: String
  let _summary: String
  let _description: String
  let _file_path: String
  let _filename: String
  let _md5_hex: String
  let _timers: Timers = Timers
  var _identifier: String = ""
  var _upload_url: String = ""
  var _slug: String = ""
  var _retry_count: U32 = 0
  var _sync_attempt: U32 = 0
  var _sync_poll_ms: U64 = 5_000
  var _done: Bool = false

  new create(
    env: Env,
    tcp_auth: TCPConnectAuth,
    ssl_ctx: SSLContext val,
    file_auth: FileAuth,
    api_key: String val,
    owner: String val,
    repo: String val,
    version: String val,
    summary: String val,
    description: String val,
    file_path: String val,
    filename: String val,
    md5_hex: String val)
  =>
    _env = env
    _tcp_auth = tcp_auth
    _ssl_ctx = ssl_ctx
    _file_auth = file_auth
    _api_key = api_key
    _owner = owner
    _repo = repo
    _version = version
    _summary = summary
    _description = description
    _file_path = file_path
    _filename = filename
    _md5_hex = md5_hex
    _request_upload_slot()

  fun ref _schedule(delay_ms: U64, cb: {()} val) =>
    let timer =
      Timer(
        object iso is TimerNotify
          let _cb: {()} val = cb

          fun ref apply(
            timer: Timer,
            count: U64)
            : Bool
          =>
            _cb()
            false
        end,
        delay_ms * 1_000_000)
    _timers(consume timer)

  fun ref _check_retryable_or_fail(
    step_name: String,
    response: http_client.HTTPResponse val,
    retry_action: {()} val)
    : Bool
  =>
    if RetryPolicy.is_retryable(response.status) then
      if _retry_count >= 5 then
        _fail(
          step_name + " failed after retries: " +
            response.status.string())
        return true
      end
      let delay = RetryPolicy.delay(_retry_count)
      _retry_count = _retry_count + 1
      _env.err.print(
        "retrying " + step_name + " in " +
          delay.string() + "ms...")
      _schedule(delay, retry_action)
      return true
    end
    if (response.status < 200) or
      (response.status >= 300)
    then
      _fail(
        step_name + " failed: " +
          response.status.string() + " " +
          response.reason + " " +
          String.from_array(response.body))
      return true
    end
    false

  be _request_upload_slot() =>
    if _done then return end
    _env.err.print("requesting upload slot...")
    let body =
      Steps.build_slot_request_body(
        _filename, _md5_hex)
    let path: String iso =
      "/files/" + _owner + "/" + _repo + "/"
    let req =
      http_client.Request.post(consume path)
        .header("X-Api-Key", _api_key)
        .json_body(body)
        .build()
    let self: Uploader tag = this
    APIConnection(
      _tcp_auth,
      _ssl_ctx,
      _api_host,
      _api_port,
      req,
      {(result: APIResult)(self) =>
        match \exhaustive\ result
        | let r: http_client.HTTPResponse val =>
          self._on_slot_response(r)
        | let e: APIError val =>
          self._retry_or_fail(
            "upload slot request",
            {()(self) =>
              self._request_upload_slot()
            },
            e.message)
        end
      })

  be _on_slot_response(
    response: http_client.HTTPResponse val)
  =>
    if _done then return end
    let self: Uploader tag = this
    if _check_retryable_or_fail(
      "upload slot request",
      response,
      {()(self) => self._request_upload_slot() })
    then return end
    let body_str = String.from_array(response.body)
    match \exhaustive\ Steps.parse_slot_response(
      body_str)
    | (SlotOK, let id: String val,
      let url: String val) =>
      _identifier = id
      _upload_url = url
      _retry_count = 0
      _env.err.print(
        "upload slot acquired: " + _identifier)
      _start_chunk_upload()
    | (SlotError, let err: String val) =>
      _fail("upload slot response: " + err)
    end

  be _start_chunk_upload() =>
    if _done then return end
    match Steps.parse_upload_url(_upload_url)
    | (let host: String val,
      let port: String val,
      let path: String val) =>
      _env.err.print(
        "uploading chunks to " + host + "...")
      let self: Uploader tag = this
      ChunkedUploader(
        _tcp_auth,
        _ssl_ctx,
        host,
        port,
        path,
        _identifier,
        _api_key,
        _file_auth,
        _file_path,
        {(result: ChunkUploadResult)(self) =>
          match \exhaustive\ result
          | None =>
            self._on_chunks_uploaded()
          | let e: ChunkUploadError val =>
            self._fail(e.message)
          end
        })
    else
      _fail(
        "failed to parse upload URL: " +
          _upload_url)
    end

  be _on_chunks_uploaded() =>
    if _done then return end
    _env.err.print(
      "chunks uploaded, completing...")
    _retry_count = 0
    _send_completion()

  be _send_completion() =>
    if _done then return end
    let body =
      Steps.build_completion_body(_identifier)
    let path: String iso =
      "/files/" + _owner + "/" + _repo + "/" +
        _identifier + "/complete/"
    let req =
      http_client.Request.post(consume path)
        .header("X-Api-Key", _api_key)
        .json_body(body)
        .build()
    let self: Uploader tag = this
    APIConnection(
      _tcp_auth,
      _ssl_ctx,
      _api_host,
      _api_port,
      req,
      {(result: APIResult)(self) =>
        match \exhaustive\ result
        | let r: http_client.HTTPResponse val =>
          self._on_completion_response(r)
        | let e: APIError val =>
          self._retry_or_fail(
            "completion request",
            {()(self) =>
              self._send_completion()
            },
            e.message)
        end
      })

  be _on_completion_response(
    response: http_client.HTTPResponse val)
  =>
    if _done then return end
    let self: Uploader tag = this
    if _check_retryable_or_fail(
      "completion request",
      response,
      {()(self) => self._send_completion() })
    then return end
    _env.err.print("upload complete")
    _retry_count = 0
    _create_package()

  be _create_package() =>
    if _done then return end
    _env.err.print("creating package record...")
    let body =
      Steps.build_package_create_body(
        _identifier,
        _version,
        _summary,
        _description)
    let path: String iso =
      "/packages/" + _owner + "/" + _repo +
        "/upload/raw/"
    let req =
      http_client.Request.post(consume path)
        .header("X-Api-Key", _api_key)
        .json_body(body)
        .build()
    let self: Uploader tag = this
    APIConnection(
      _tcp_auth,
      _ssl_ctx,
      _api_host,
      _api_port,
      req,
      {(result: APIResult)(self) =>
        match \exhaustive\ result
        | let r: http_client.HTTPResponse val =>
          self._on_create_package_response(r)
        | let e: APIError val =>
          self._retry_or_fail(
            "package creation",
            {()(self) =>
              self._create_package()
            },
            e.message)
        end
      })

  be _on_create_package_response(
    response: http_client.HTTPResponse val)
  =>
    if _done then return end
    let self: Uploader tag = this
    if _check_retryable_or_fail(
      "package creation",
      response,
      {()(self) => self._create_package() })
    then return end
    let body_str = String.from_array(response.body)
    match \exhaustive\
      Steps.parse_package_create_response(body_str)
    | (PackageCreateOK, let slug: String val) =>
      _slug = slug
      _retry_count = 0
      _env.err.print(
        "package created: " + _slug)
      _poll_sync_status()
    | (PackageCreateError, let err: String val) =>
      _fail(
        "package creation response: " + err)
    end

  be _poll_sync_status() =>
    if _done then return end
    let path: String iso =
      "/packages/" + _owner + "/" + _repo + "/" +
        _slug + "/status/"
    let req =
      http_client.Request.get(consume path)
        .header("X-Api-Key", _api_key)
        .build()
    let self: Uploader tag = this
    APIConnection(
      _tcp_auth,
      _ssl_ctx,
      _api_host,
      _api_port,
      req,
      {(result: APIResult)(self) =>
        match \exhaustive\ result
        | let r: http_client.HTTPResponse val =>
          self._on_sync_status_response(r)
        | let e: APIError val =>
          self._retry_or_fail(
            "sync status check",
            {()(self) =>
              self._poll_sync_status()
            },
            e.message)
        end
      })

  be _on_sync_status_response(
    response: http_client.HTTPResponse val)
  =>
    if _done then return end
    let self: Uploader tag = this
    if _check_retryable_or_fail(
      "sync status check",
      response,
      {()(self) => self._poll_sync_status() })
    then return end
    let body_str = String.from_array(response.body)
    match \exhaustive\ Steps.parse_sync_status(
      body_str)
    | (SyncCompleted, let msg: String val) =>
      _done = true
      _timers.dispose()
      _env.err.print(msg)
      _env.exitcode(0)
    | (SyncFailed, let reason: String val) =>
      if reason.contains("should be deleted") then
        _fail(
          "sync failed (not recoverable): " +
            reason)
        return
      end
      _sync_attempt = _sync_attempt + 1
      if _sync_attempt >= 3 then
        _fail(
          "sync failed after " +
            _sync_attempt.string() +
            " attempts: " + reason)
        return
      end
      _env.err.print(
        "sync failed, requesting resync " +
          "(attempt " +
          (_sync_attempt + 1).string() +
          "/3)...")
      _retry_count = 0
      _request_resync()
    | (SyncInProgress,
      let status: String val) =>
      _env.err.print("syncing: " + status)
      _retry_count = 0
      let delay = _sync_poll_ms
      if _sync_poll_ms < 300_000 then
        _sync_poll_ms = _sync_poll_ms + 5_000
      end
      _schedule(
        delay,
        {()(self) =>
          self._poll_sync_status()
        })
    end

  be _request_resync() =>
    if _done then return end
    let path: String iso =
      "/packages/" + _owner + "/" + _repo + "/" +
        _slug + "/resync/"
    let req =
      http_client.Request.post(consume path)
        .header("X-Api-Key", _api_key)
        .build()
    let self: Uploader tag = this
    APIConnection(
      _tcp_auth,
      _ssl_ctx,
      _api_host,
      _api_port,
      req,
      {(result: APIResult)(self) =>
        match \exhaustive\ result
        | let r: http_client.HTTPResponse val =>
          self._on_resync_response(r)
        | let e: APIError val =>
          self._retry_or_fail(
            "resync request",
            {()(self) =>
              self._request_resync()
            },
            e.message)
        end
      })

  be _on_resync_response(
    response: http_client.HTTPResponse val)
  =>
    if _done then return end
    let self: Uploader tag = this
    if _check_retryable_or_fail(
      "resync request",
      response,
      {()(self) => self._request_resync() })
    then return end
    _env.err.print("resync requested, polling...")
    _retry_count = 0
    _sync_poll_ms = 5_000
    _poll_sync_status()

  be _retry_or_fail(
    step_name: String,
    retry_action: {()} val,
    error_msg: String)
  =>
    if _done then return end
    if _retry_count >= 5 then
      _fail(
        step_name + " failed after retries: " +
          error_msg)
      return
    end
    let delay = RetryPolicy.delay(_retry_count)
    _retry_count = _retry_count + 1
    _env.err.print(
      "retrying " + step_name + " in " +
        delay.string() + "ms (" +
        error_msg + ")...")
    _schedule(delay, retry_action)

  be _fail(message: String) =>
    if _done then return end
    _done = true
    _timers.dispose()
    _env.err.print("error: " + message)
    _env.exitcode(1)
