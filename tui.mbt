///|
pub fn render_tui(
  state : AppState,
  width : Int,
  height : Int,
) -> @tui.TuiNode {
  let unread = state.unread_count()
  let visible = state.visible_comments()
  let filter_label = if state.show_read { "all" } else { "unread only" }
  @tui.view(
    width=width.to_double(),
    height=height.to_double(),
    border="rounded",
    border_color="cyan",
    [
      // Header
      @tui.row(justify="space-between", margin_y=1.0, padding_x=1.0, [
        @tui.text("GitHub PR Notifier", fg="yellow", bold=true),
        @tui.row(gap=2.0, [
          @tui.text("[\{unread} unread]", fg="cyan"),
          @tui.text("[\{filter_label}]", fg="rgb(128,128,128)"),
        ]),
      ]),
      // Comment list
      @tui.column(
        flex_grow=1.0,
        padding_x=1.0,
        render_comment_list(visible, state.cursor),
      ),
      // Footer
      @tui.row(justify="center", padding_y=1.0, [
        @tui.text(
          "j/k:move  r:read  R:read all  o:open  f:filter  q:quit",
          fg="rgb(128,128,128)",
        ),
      ]),
    ],
  )
}

///|
fn render_comment_list(
  visible : Array[Comment],
  cursor : Int,
) -> Array[@tui.TuiNode] {
  if visible.is_empty() {
    return [@tui.text("  No comments.")]
  }
  let nodes : Array[@tui.TuiNode] = []
  let mut current_pr = ""
  for i, c in visible {
    let pr_key = "\{c.pr_repo}#\{c.pr_number}"
    if pr_key != current_pr {
      current_pr = pr_key
      if i > 0 {
        nodes.push(@tui.vspace(1.0))
      }
      nodes.push(
        @tui.text(
          "\{c.pr_repo} #\{c.pr_number}: \{c.pr_title}",
          fg="white",
          bold=true,
        ),
      )
    }
    let marker = if c.read { " " } else { "*" }
    let cursor_mark = if i == cursor { ">" } else { " " }
    let preview = truncate_str(c.body.replace_all(old="\n", new=" "), 50)
    let line = "\{cursor_mark} \{marker} @\{c.author}  \{c.created_at}  \"\{preview}\""
    if i == cursor {
      nodes.push(
        @tui.row(bg="white", [
          @tui.text(line, fg="black", bold=true),
        ]),
      )
    } else {
      nodes.push(@tui.text(line))
    }
  }
  nodes
}

///|
fn truncate_str(s : String, max : Int) -> String {
  if s.length() <= max {
    s
  } else {
    try {
      s[:max].to_string() + "..."
    } catch {
      _ => s
    }
  }
}
