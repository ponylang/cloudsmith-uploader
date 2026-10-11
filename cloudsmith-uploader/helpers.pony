primitive EnvVar
  """
  Looks up an environment variable by name from the
  process environment array.
  """
  fun apply(vars: Array[String] val, name: String)
    : (String val | None)
  =>
    let prefix: String val = name + "="
    for v in vars.values() do
      if v.at(prefix) then
        return v.substring(prefix.size().isize())
      end
    end
    None

primitive RetryPolicy
  """
  HTTP retry classification and exponential backoff
  delay computation.
  """
  fun is_retryable(status: U16): Bool =>
    """
    True for HTTP statuses that warrant a retry:
    429, 500, 502, 503, and 504.
    """
    (status == 429) or (status == 500) or
      (status == 502) or (status == 503) or
      (status == 504)

  fun delay(retry_count: U32): U64 =>
    """
    Milliseconds to wait before the next retry.
    Exponential backoff: 250ms * 2^retry_count.
    """
    let base: U64 = 250
    var d: U64 = base
    var i: U32 = 0
    while i < retry_count do
      d = d * 2
      i = i + 1
    end
    d
