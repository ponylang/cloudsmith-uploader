use "pony_test"
use "../cloudsmith-uploader"

class \nodoc\ _TestRetryPolicyIsRetryable429
  is UnitTest
  fun name(): String =>
    "RetryPolicy.is_retryable - 429"

  fun apply(h: TestHelper) =>
    h.assert_true(RetryPolicy.is_retryable(429))

class \nodoc\ _TestRetryPolicyIsRetryable500
  is UnitTest
  fun name(): String =>
    "RetryPolicy.is_retryable - 500"

  fun apply(h: TestHelper) =>
    h.assert_true(RetryPolicy.is_retryable(500))

class \nodoc\ _TestRetryPolicyIsRetryable502
  is UnitTest
  fun name(): String =>
    "RetryPolicy.is_retryable - 502"

  fun apply(h: TestHelper) =>
    h.assert_true(RetryPolicy.is_retryable(502))

class \nodoc\ _TestRetryPolicyIsRetryable503
  is UnitTest
  fun name(): String =>
    "RetryPolicy.is_retryable - 503"

  fun apply(h: TestHelper) =>
    h.assert_true(RetryPolicy.is_retryable(503))

class \nodoc\ _TestRetryPolicyIsRetryable504
  is UnitTest
  fun name(): String =>
    "RetryPolicy.is_retryable - 504"

  fun apply(h: TestHelper) =>
    h.assert_true(RetryPolicy.is_retryable(504))

class \nodoc\ _TestRetryPolicyNotRetryable200
  is UnitTest
  fun name(): String =>
    "RetryPolicy.is_retryable - 200 not retryable"

  fun apply(h: TestHelper) =>
    h.assert_false(RetryPolicy.is_retryable(200))

class \nodoc\ _TestRetryPolicyNotRetryable400
  is UnitTest
  fun name(): String =>
    "RetryPolicy.is_retryable - 400 not retryable"

  fun apply(h: TestHelper) =>
    h.assert_false(RetryPolicy.is_retryable(400))

class \nodoc\ _TestRetryPolicyNotRetryable404
  is UnitTest
  fun name(): String =>
    "RetryPolicy.is_retryable - 404 not retryable"

  fun apply(h: TestHelper) =>
    h.assert_false(RetryPolicy.is_retryable(404))

class \nodoc\ _TestRetryPolicyNotRetryable501
  is UnitTest
  fun name(): String =>
    "RetryPolicy.is_retryable - 501 not retryable"

  fun apply(h: TestHelper) =>
    h.assert_false(RetryPolicy.is_retryable(501))

class \nodoc\ _TestRetryPolicyDelay is UnitTest
  fun name(): String =>
    "RetryPolicy.delay - exponential backoff"

  fun apply(h: TestHelper) =>
    h.assert_eq[U64](RetryPolicy.delay(0), 250)
    h.assert_eq[U64](RetryPolicy.delay(1), 500)
    h.assert_eq[U64](RetryPolicy.delay(2), 1000)
    h.assert_eq[U64](RetryPolicy.delay(3), 2000)
    h.assert_eq[U64](RetryPolicy.delay(4), 4000)
    h.assert_eq[U64](RetryPolicy.delay(5), 8000)

class \nodoc\ _TestEnvVarFound is UnitTest
  fun name(): String =>
    "EnvVar - found"

  fun apply(h: TestHelper) =>
    let vars: Array[String] val =
      ["FOO=bar"; "BAZ=qux"]
    match \exhaustive\ EnvVar(vars, "FOO")
    | let v: String =>
      h.assert_eq[String](v, "bar")
    | None =>
      h.fail("should have found FOO")
    end

class \nodoc\ _TestEnvVarNotFound is UnitTest
  fun name(): String =>
    "EnvVar - not found"

  fun apply(h: TestHelper) =>
    let vars: Array[String] val =
      ["FOO=bar"; "BAZ=qux"]
    match \exhaustive\ EnvVar(vars, "MISSING")
    | let _: String =>
      h.fail("should not have found MISSING")
    | None => None
    end

class \nodoc\ _TestEnvVarEmptyValue is UnitTest
  fun name(): String =>
    "EnvVar - empty value"

  fun apply(h: TestHelper) =>
    let vars: Array[String] val = ["KEY="]
    match \exhaustive\ EnvVar(vars, "KEY")
    | let v: String =>
      h.assert_eq[String](v, "")
    | None =>
      h.fail("should have found KEY with empty value")
    end

class \nodoc\ _TestEnvVarPrefixMatch is UnitTest
  fun name(): String =>
    "EnvVar - prefix not confused with full name"

  fun apply(h: TestHelper) =>
    let vars: Array[String] val =
      ["FOOBAR=wrong"; "FOO=right"]
    match \exhaustive\ EnvVar(vars, "FOO")
    | let v: String =>
      h.assert_eq[String](v, "right")
    | None =>
      h.fail("should have found FOO")
    end

class \nodoc\ _TestEnvVarEqualsInValue is UnitTest
  fun name(): String =>
    "EnvVar - equals sign in value"

  fun apply(h: TestHelper) =>
    let vars: Array[String] val =
      ["FOO=bar=baz"]
    match \exhaustive\ EnvVar(vars, "FOO")
    | let v: String =>
      h.assert_eq[String](v, "bar=baz")
    | None =>
      h.fail("should have found FOO")
    end

class \nodoc\ _TestEnvVarEmptyVars is UnitTest
  fun name(): String =>
    "EnvVar - empty vars array"

  fun apply(h: TestHelper) =>
    let vars: Array[String] val = []
    match \exhaustive\ EnvVar(vars, "FOO")
    | let _: String =>
      h.fail("should not find in empty array")
    | None => None
    end
