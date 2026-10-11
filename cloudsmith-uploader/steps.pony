use "json"
use uri_pkg = "uri"

primitive SlotOK
  """
  Carries the upload identifier and upload URL.
  """

primitive SlotError
  """
  Carries a diagnostic message.
  """

type SlotResult is
  ((SlotOK, String val, String val)
  | (SlotError, String val))

primitive SyncCompleted
  """
  Carries a status message.
  """

primitive SyncFailed
  """
  Carries the status_reason from the API.
  """

primitive SyncInProgress
  """
  Carries a stage and progress string.
  """

type SyncResult is
  ( (SyncCompleted, String val)
  | (SyncFailed, String val)
  | (SyncInProgress, String val) )

primitive PackageCreateOK
  """
  Carries the package slug.
  """

primitive PackageCreateError
  """
  Carries a diagnostic message.
  """

type PackageCreateResult is
  ((PackageCreateOK, String val)
  | (PackageCreateError, String val))

primitive Steps
  """
  Builds and parses Cloudsmith API request/response JSON.
  """

  fun build_slot_request_body(
    filename: String,
    md5_hex: String)
    : String
  =>
    """
    JSON body for the upload slot POST. Always requests chunked
    upload via put_parts.
    """
    let obj = JSONObject
      .update("filename", filename)
      .update("md5_checksum", md5_hex)
      .update("method", "put_parts")
    JSONPrinter.print(obj)

  fun parse_slot_response(body: String)
    : SlotResult
  =>
    """
    Extracts the upload identifier and upload URL from a slot
    response, or returns an error message.
    """
    match JSONParser.parse(body)
    | let obj: JSONObject =>
      try
        let identifier =
          obj("identifier")? as String
        let upload_url =
          obj("upload_url")? as String
        (SlotOK, identifier, upload_url)
      else
        (SlotError,
          "missing identifier or upload_url" +
            " in response")
      end
    else
      (SlotError, "invalid JSON in slot response")
    end

  fun build_completion_body(identifier: String)
    : String
  =>
    """
    JSON body for the upload completion POST.
    """
    let obj = JSONObject
      .update("upload_id", identifier)
      .update("complete", true)
    JSONPrinter.print(obj)

  fun build_package_create_body(
    identifier: String,
    version: String,
    summary: String,
    description: String)
    : String
  =>
    """
    JSON body for the package creation POST.
    """
    let obj = JSONObject
      .update("package_file", identifier)
      .update("version", version)
      .update("summary", summary)
      .update("description", description)
    JSONPrinter.print(obj)

  fun parse_package_create_response(body: String)
    : PackageCreateResult
  =>
    """
    Extracts the package slug from a creation response, or
    returns an error with a diagnostic message.
    """
    match JSONParser.parse(body)
    | let obj: JSONObject =>
      try
        (PackageCreateOK, obj("slug")? as String)
      else
        (PackageCreateError,
          "missing slug in response")
      end
    else
      (PackageCreateError,
        "invalid JSON in package response")
    end

  fun parse_sync_status(body: String): SyncResult =>
    """
    Parses a sync status response into completed, failed, or
    in-progress with a human-readable progress string.
    """
    match JSONParser.parse(body)
    | let obj: JSONObject =>
      let completed =
        try obj("is_sync_completed")? as Bool
        else false
        end
      let failed =
        try obj("is_sync_failed")? as Bool
        else false
        end
      let reason =
        try obj("status_reason")? as String
        else ""
        end
      let stage =
        try obj("stage_str")? as String
        else ""
        end
      if completed then
        (SyncCompleted, "sync completed")
      elseif failed then
        (SyncFailed, reason)
      else
        let progress =
          try
            let p =
              obj("sync_progress")? as I64
            p.string() + "%"
          else
            "unknown"
          end
        (SyncInProgress,
          stage + " (" + progress + ")")
      end
    else
      (SyncFailed,
        "invalid JSON in status response")
    end

  fun parse_upload_url(url_string: String)
    : ((String val, String val, String val) | None)
  =>
    """
    Splits an upload URL into (host, port, request_path) for
    the chunk uploader. Defaults port to "443" when absent.
    """
    match \exhaustive\ uri_pkg.ParseURI(url_string)
    | let parsed: uri_pkg.URI val =>
      match parsed.scheme
      | "https" => None
      else return None
      end
      match parsed.authority
      | let auth: uri_pkg.URIAuthority =>
        let port: String val =
          match \exhaustive\ auth.port
          | let p: U16 => p.string()
          | None => "443"
          end
        var request_path: String val =
          if parsed.path == "" then "/"
          else parsed.path
          end
        match parsed.query
        | let q: String =>
          request_path = request_path + "?" + q
        end
        (auth.host, port, request_path)
      end
    | let _: uri_pkg.URIParseError val =>
      None
    end
