///|
pub async fn send_notification_cmux(title : String, body : String) -> Unit {
  let _ = @process.run("cmux", ["notify", "--title", title, "--body", body][:])
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
