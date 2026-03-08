///|
pub fn truncate_body(body : String, max_len : Int) -> String {
  let buf = StringBuilder::new()
  let mut count = 0
  for ch in body {
    if count >= max_len - 3 {
      buf.write_string("...")
      break
    }
    if ch == '\n' || ch == '\r' || ch == '\t' {
      buf.write_char(' ')
    } else {
      buf.write_char(ch)
    }
    count += 1
  }
  buf.to_string()
}

///|
pub async fn send_notification_cmux(title : String, body : String) -> Unit {
  let sanitized = truncate_body(body, 256)
  let (exit_code, _, stderr) = @process.collect_output(
    "cmux",
    ["notify", "--title", title, "--body", sanitized][:],
  )
  if exit_code != 0 {
    let err = stderr.text()
    println(
      "Failed to send notification with cmux (exit code \{exit_code}): \{err}",
    )
    println("  title: \{title}")
    println("  body: \{body}")
    println("Falling back to osascript")
    send_notification_osascript(title, body)
  }
}

///|
pub async fn send_notification_osascript(title : String, body : String) -> Unit {
  let escaped_body = body
    .replace_all(old="\\", new="\\\\")
    .replace_all(old="\"", new="\\\"")
  let escaped_title = title
    .replace_all(old="\\", new="\\\\")
    .replace_all(old="\"", new="\\\"")
  let script = "display notification \"\{escaped_body}\" with title \"\{escaped_title}\""
  let _ = @process.run("osascript", ["-e", script][:])
}
