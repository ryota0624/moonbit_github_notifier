///|
let esc : String = "\u001b"

///|
pub fn render(state : AppState) -> String raise {
  let buf = StringBuilder::new()
  let unread = state.unread_count()
  buf.write_string("\{esc}[2J\{esc}[H")
  buf.write_string("\{esc}[1mGitHub PR Notifier\{esc}[0m")
  buf.write_string("                    [\{unread} unread]")
  if state.show_read {
    buf.write_string(" [all]")
  } else {
    buf.write_string(" [unread only]")
  }
  buf.write_string("\n")
  buf.write_string(
    "──────────────────────────────────────────────────────────────────\n",
  )
  let visible = state.visible_comments()
  if visible.is_empty() {
    buf.write_string("  No comments.\n")
  } else {
    let mut current_pr = ""
    for i, c in visible {
      let pr_key = "\{c.pr_repo}#\{c.pr_number}"
      if pr_key != current_pr {
        current_pr = pr_key
        if i > 0 {
          buf.write_string("\n")
        }
        buf.write_string(
          " \{esc}[1m\{c.pr_repo} #\{c.pr_number}: \{c.pr_title}\{esc}[0m\n",
        )
      }
      let marker = if c.read { " " } else { "*" }
      let cursor_mark = if i == state.cursor { ">" } else { " " }
      let preview = truncate(c.body.replace_all(old="\n", new=" "), 50)
      if i == state.cursor {
        buf.write_string(
          "\{esc}[7m\{cursor_mark} \{marker} @\{c.author}  \{c.created_at}  \"\{preview}\"\{esc}[0m\n",
        )
      } else {
        buf.write_string(
          "\{cursor_mark} \{marker} @\{c.author}  \{c.created_at}  \"\{preview}\"\n",
        )
      }
    }
  }
  buf.write_string(
    "──────────────────────────────────────────────────────────────────\n",
  )
  buf.write_string(" j/k:move  r:read  R:read all  o:open  f:filter  q:quit\n")
  buf.to_string()
}

///|
fn truncate(s : String, max : Int) -> String raise {
  if s.length() <= max {
    s
  } else {
    s[:max].to_string() + "..."
  }
}
