use "pony_test"
use "json"
use "../cloudsmith-uploader"

class \nodoc\ _TestBuildSlotRequestBody is UnitTest
  fun name(): String =>
    "Steps.build_slot_request_body"

  fun apply(h: TestHelper) =>
    let body =
      Steps.build_slot_request_body(
        "ponyc-x86-64.tar.gz", "ab12cd34ef56")
    match JSONParser.parse(body)
    | let obj: JSONObject =>
      try
        h.assert_eq[String](
          obj("filename")? as String,
          "ponyc-x86-64.tar.gz")
        h.assert_eq[String](
          obj("md5_checksum")? as String,
          "ab12cd34ef56")
        h.assert_eq[String](
          obj("method")? as String,
          "put_parts")
      else
        h.fail("missing expected fields")
      end
    else
      h.fail("not valid JSON: " + body)
    end

class \nodoc\ _TestParseSlotResponseOK is UnitTest
  fun name(): String =>
    "Steps.parse_slot_response - ok"

  fun apply(h: TestHelper) =>
    let body =
      """
      {"identifier":"abc123","upload_url":"https://s3.amazonaws.com/bucket/path?sig=x","upload_fields":{"key":"val"}}
      """
    match \exhaustive\ Steps.parse_slot_response(
      body)
    | (SlotOK, let id: String val,
      let url: String val) =>
      h.assert_eq[String](id, "abc123")
      h.assert_eq[String](
        url,
        "https://s3.amazonaws.com/bucket/" +
          "path?sig=x")
    | (SlotError, let err: String val) =>
      h.fail("unexpected error: " + err)
    end

class \nodoc\ _TestParseSlotResponseMissingFields
  is UnitTest
  fun name(): String =>
    "Steps.parse_slot_response - missing fields"

  fun apply(h: TestHelper) =>
    let body = """{"identifier":"abc123"}"""
    match \exhaustive\ Steps.parse_slot_response(
      body)
    | (SlotOK, _, _) =>
      h.fail("should have failed")
    | (SlotError, let err: String val) =>
      h.assert_true(
        err.contains("missing"))
    end

class \nodoc\ _TestParseSlotResponseInvalidJSON
  is UnitTest
  fun name(): String =>
    "Steps.parse_slot_response - invalid JSON"

  fun apply(h: TestHelper) =>
    match \exhaustive\ Steps.parse_slot_response(
      "not json")
    | (SlotOK, _, _) =>
      h.fail("should have failed")
    | (SlotError, let err: String val) =>
      h.assert_true(
        err.contains("invalid JSON"))
    end

class \nodoc\ _TestBuildCompletionBody is UnitTest
  fun name(): String =>
    "Steps.build_completion_body"

  fun apply(h: TestHelper) =>
    let body =
      Steps.build_completion_body("abc123")
    match JSONParser.parse(body)
    | let obj: JSONObject =>
      try
        h.assert_eq[String](
          obj("upload_id")? as String, "abc123")
        h.assert_true(
          obj("complete")? as Bool)
      else
        h.fail("missing expected fields")
      end
    else
      h.fail("not valid JSON")
    end

class \nodoc\ _TestBuildPackageCreateBody
  is UnitTest
  fun name(): String =>
    "Steps.build_package_create_body"

  fun apply(h: TestHelper) =>
    let body =
      Steps.build_package_create_body(
        "abc123",
        "0.59.1",
        "Pony compiler",
        "https://github.com/ponylang/ponyc")
    match JSONParser.parse(body)
    | let obj: JSONObject =>
      try
        h.assert_eq[String](
          obj("package_file")? as String,
          "abc123")
        h.assert_eq[String](
          obj("version")? as String,
          "0.59.1")
        h.assert_eq[String](
          obj("summary")? as String,
          "Pony compiler")
        h.assert_eq[String](
          obj("description")? as String,
          "https://github.com/ponylang/ponyc")
      else
        h.fail("missing expected fields")
      end
    else
      h.fail("not valid JSON")
    end

class \nodoc\ _TestParsePackageCreateResponse
  is UnitTest
  fun name(): String =>
    "Steps.parse_package_create_response"

  fun apply(h: TestHelper) =>
    let body =
      """{"slug":"ponyc-abc123","slug_perm":"xyz"}"""
    match \exhaustive\
      Steps.parse_package_create_response(body)
    | (PackageCreateOK, let slug: String val) =>
      h.assert_eq[String](slug, "ponyc-abc123")
    | (PackageCreateError, let err: String val) =>
      h.fail("unexpected error: " + err)
    end

class \nodoc\ _TestParsePackageCreateResponseMissing
  is UnitTest
  fun name(): String =>
    "Steps.parse_package_create_response" +
      " - missing slug"

  fun apply(h: TestHelper) =>
    let body = """{"slug_perm":"xyz"}"""
    match \exhaustive\
      Steps.parse_package_create_response(body)
    | (PackageCreateOK, _) =>
      h.fail("should have failed")
    | (PackageCreateError, let err: String val) =>
      h.assert_true(
        err.contains("missing slug"))
    end

class \nodoc\ _TestParseSyncStatusCompleted
  is UnitTest
  fun name(): String =>
    "Steps.parse_sync_status - completed"

  fun apply(h: TestHelper) =>
    let body =
      """{"is_sync_completed":true,"is_sync_failed":false}"""
    match \exhaustive\ Steps.parse_sync_status(
      body)
    | (SyncCompleted, let s: String val) =>
      h.assert_eq[String](s, "sync completed")
    | (SyncFailed, let r: String val) =>
      h.fail("unexpected failed: " + r)
    | (SyncInProgress, _) =>
      h.fail("unexpected in progress")
    end

class \nodoc\ _TestParseSyncStatusFailed
  is UnitTest
  fun name(): String =>
    "Steps.parse_sync_status - failed"

  fun apply(h: TestHelper) =>
    let body =
      """{"is_sync_completed":false,"is_sync_failed":true,"status_reason":"checksum mismatch"}"""
    match \exhaustive\ Steps.parse_sync_status(
      body)
    | (SyncCompleted, _) =>
      h.fail("unexpected completed")
    | (SyncFailed, let r: String val) =>
      h.assert_eq[String](r, "checksum mismatch")
    | (SyncInProgress, _) =>
      h.fail("unexpected in progress")
    end

class \nodoc\ _TestParseSyncStatusInProgress
  is UnitTest
  fun name(): String =>
    "Steps.parse_sync_status - in progress"

  fun apply(h: TestHelper) =>
    let body =
      """{"is_sync_completed":false,"is_sync_failed":false,"stage_str":"Synchronising","sync_progress":50}"""
    match \exhaustive\ Steps.parse_sync_status(
      body)
    | (SyncCompleted, _) =>
      h.fail("unexpected completed")
    | (SyncFailed, _) =>
      h.fail("unexpected failed")
    | (SyncInProgress, let s: String val) =>
      h.assert_eq[String](
        s, "Synchronising (50%)")
    end

class \nodoc\ _TestParseSyncStatusNoProgress
  is UnitTest
  fun name(): String =>
    "Steps.parse_sync_status - no progress"

  fun apply(h: TestHelper) =>
    let body =
      """{"is_sync_completed":false,"is_sync_failed":false,"stage_str":"Waiting"}"""
    match \exhaustive\ Steps.parse_sync_status(
      body)
    | (SyncCompleted, _) =>
      h.fail("unexpected completed")
    | (SyncFailed, _) =>
      h.fail("unexpected failed")
    | (SyncInProgress, let s: String val) =>
      h.assert_eq[String](
        s, "Waiting (unknown)")
    end

class \nodoc\ _TestParseSyncStatusBothTrue
  is UnitTest
  fun name(): String =>
    "Steps.parse_sync_status" +
      " - completed+failed both true"

  fun apply(h: TestHelper) =>
    let body =
      """{"is_sync_completed":true,"is_sync_failed":true,"status_reason":"stale"}"""
    match \exhaustive\ Steps.parse_sync_status(
      body)
    | (SyncCompleted, let s: String val) =>
      h.assert_eq[String](s, "sync completed")
    | (SyncFailed, _) =>
      h.fail("completed should take precedence")
    | (SyncInProgress, _) =>
      h.fail("unexpected in progress")
    end

class \nodoc\ _TestParseSyncStatusInvalidJSON
  is UnitTest
  fun name(): String =>
    "Steps.parse_sync_status - invalid JSON"

  fun apply(h: TestHelper) =>
    match \exhaustive\ Steps.parse_sync_status(
      "not json")
    | (SyncCompleted, _) =>
      h.fail("unexpected completed")
    | (SyncFailed, let err: String val) =>
      h.assert_true(
        err.contains("invalid JSON"))
    | (SyncInProgress, _) =>
      h.fail("unexpected in progress")
    end

class \nodoc\ _TestParsePackageCreateInvalidJSON
  is UnitTest
  fun name(): String =>
    "Steps.parse_package_create_response" +
      " - invalid JSON"

  fun apply(h: TestHelper) =>
    match \exhaustive\
      Steps.parse_package_create_response(
        "not json")
    | (PackageCreateOK, _) =>
      h.fail("should have failed")
    | (PackageCreateError, let err: String val) =>
      h.assert_true(
        err.contains("invalid JSON"))
    end

class \nodoc\ _TestParseSyncStatusMissingFields
  is UnitTest
  fun name(): String =>
    "Steps.parse_sync_status - missing booleans"

  fun apply(h: TestHelper) =>
    let body = """{"stage_str":"Waiting"}"""
    match \exhaustive\ Steps.parse_sync_status(
      body)
    | (SyncCompleted, _) =>
      h.fail("unexpected completed")
    | (SyncFailed, _) =>
      h.fail("unexpected failed")
    | (SyncInProgress, let s: String val) =>
      h.assert_eq[String](
        s, "Waiting (unknown)")
    end

class \nodoc\ _TestParseSyncStatusWrongType
  is UnitTest
  fun name(): String =>
    "Steps.parse_sync_status" +
      " - wrong type for boolean"

  fun apply(h: TestHelper) =>
    let body =
      """{"is_sync_completed":"true","is_sync_failed":false}"""
    match \exhaustive\ Steps.parse_sync_status(
      body)
    | (SyncCompleted, _) =>
      h.fail(
        "string 'true' should not match Bool")
    | (SyncFailed, _) =>
      h.fail("unexpected failed")
    | (SyncInProgress, let s: String val) =>
      h.assert_eq[String](s, " (unknown)")
    end

class \nodoc\ _TestParseUploadURLHTTPS is UnitTest
  fun name(): String =>
    "Steps.parse_upload_url - https"

  fun apply(h: TestHelper) =>
    let url =
      "https://s3.amazonaws.com/bucket/path?sig=abc"
    match \exhaustive\ Steps.parse_upload_url(url)
    | (let host: String val,
      let port: String val,
      let path: String val) =>
      h.assert_eq[String](
        host, "s3.amazonaws.com")
      h.assert_eq[String](port, "443")
      h.assert_eq[String](
        path, "/bucket/path?sig=abc")
    | None =>
      h.fail("should have parsed URL")
    end

class \nodoc\ _TestParseUploadURLWithPort
  is UnitTest
  fun name(): String =>
    "Steps.parse_upload_url - with port"

  fun apply(h: TestHelper) =>
    let url = "https://example.com:8443/upload"
    match \exhaustive\ Steps.parse_upload_url(url)
    | (let host: String val,
      let port: String val,
      let path: String val) =>
      h.assert_eq[String](host, "example.com")
      h.assert_eq[String](port, "8443")
      h.assert_eq[String](path, "/upload")
    | None =>
      h.fail("should have parsed URL")
    end

class \nodoc\ _TestParseUploadURLPortAndQuery
  is UnitTest
  fun name(): String =>
    "Steps.parse_upload_url - port and query"

  fun apply(h: TestHelper) =>
    let url =
      "https://example.com:8443/upload?sig=abc"
    match \exhaustive\ Steps.parse_upload_url(url)
    | (let host: String val,
      let port: String val,
      let path: String val) =>
      h.assert_eq[String](host, "example.com")
      h.assert_eq[String](port, "8443")
      h.assert_eq[String](
        path, "/upload?sig=abc")
    | None =>
      h.fail("should have parsed URL")
    end

class \nodoc\ _TestParseUploadURLEmptyPath
  is UnitTest
  fun name(): String =>
    "Steps.parse_upload_url - empty path"

  fun apply(h: TestHelper) =>
    match \exhaustive\ Steps.parse_upload_url(
      "https://example.com")
    | (let host: String val,
      let port: String val,
      let path: String val) =>
      h.assert_eq[String](host, "example.com")
      h.assert_eq[String](port, "443")
      h.assert_eq[String](path, "/")
    | None =>
      h.fail("should have parsed URL")
    end

class \nodoc\ _TestParseUploadURLHTTP is UnitTest
  fun name(): String =>
    "Steps.parse_upload_url - rejects http"

  fun apply(h: TestHelper) =>
    match \exhaustive\ Steps.parse_upload_url(
      "http://s3.amazonaws.com/bucket/path")
    | (_, _, _) =>
      h.fail("should have returned None for http")
    | None => None
    end

class \nodoc\ _TestParseUploadURLNoScheme
  is UnitTest
  fun name(): String =>
    "Steps.parse_upload_url - rejects no scheme"

  fun apply(h: TestHelper) =>
    match \exhaustive\ Steps.parse_upload_url(
      "//s3.amazonaws.com/bucket/path")
    | (_, _, _) =>
      h.fail(
        "should have returned None for" +
          " schemeless URL")
    | None => None
    end

class \nodoc\ _TestParseUploadURLInvalid
  is UnitTest
  fun name(): String =>
    "Steps.parse_upload_url - invalid"

  fun apply(h: TestHelper) =>
    match \exhaustive\ Steps.parse_upload_url(
      "not a url")
    | (_, _, _) =>
      h.fail("should have returned None")
    | None => None
    end
