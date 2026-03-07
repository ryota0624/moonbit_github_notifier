///|
pub fn render_tui(
  state : AppState,
  width : Int,
  height : Int,
) -> @tui.TuiNode {
  let unread = state.unread_count()
  let visible = state.visible_comments()
  let filter_label = if state.show_read { "all" } else { "unread only" }
  // Header: 3 lines (margin+text+margin), Footer: 3 lines, Border: 2 lines
  let list_height = height - 8
  state.adjust_scroll(list_height)
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
        render_comment_list(visible, state.cursor, state.scroll_offset, list_height),
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
  scroll_offset : Int,
  max_lines : Int,
) -> Array[@tui.TuiNode] {
  if visible.is_empty() {
    return [@tui.text("  No comments.")]
  }
  let nodes : Array[@tui.TuiNode] = []
  let mut current_pr = ""
  let mut line_count = 0
  for i, c in visible {
    let pr_key = "\{c.pr_repo}#\{c.pr_number}"
    let is_new_pr = pr_key != current_pr
    if is_new_pr {
      current_pr = pr_key
      // PR header takes lines: separator (if not first) + title
      if i > 0 {
        line_count += 1 // vspace
      }
      line_count += 1 // PR title
    }
    line_count += 1 // comment line
    // Skip lines before scroll_offset
    if line_count <= scroll_offset {
      continue
    }
    // Stop if we've filled the visible area
    if line_count > scroll_offset + max_lines {
      break
    }
    // Render PR header if this is the first visible item of a new PR group
    if is_new_pr {
      if nodes.length() > 0 {
        nodes.push(@tui.vspace(1.0))
      }
      nodes.push(
        @tui.row([
          @tui.text("\{c.pr_repo}", fg="cyan", bold=true),
          @tui.text(" #\{c.pr_number} ", fg="yellow"),
          @tui.text(c.pr_title, fg="white", bold=true),
        ]),
      )
    }
    let cursor_mark = if i == cursor { ">" } else { " " }
    let preview = truncate_str(c.body.replace_all(old="\n", new=" "), 50)
    if i == cursor {
      // Selected row
      nodes.push(
        @tui.row(bg="rgb(60,60,80)", [
          @tui.text("\{cursor_mark} ", fg="yellow", bold=true),
          if c.read {
            @tui.text("  ", fg="rgb(80,80,80)")
          } else {
            @tui.text("* ", fg="red", bold=true)
          },
          @tui.text("@\{c.author}", fg="cyan", bold=true),
          @tui.text("  \{c.created_at}  ", fg="rgb(180,180,180)"),
          @tui.text("\"\{preview}\"", fg="white", bold=true),
        ]),
      )
    } else {
      // Normal row
      let author_color = if c.read { "rgb(100,100,100)" } else { "green" }
      let body_color = if c.read { "rgb(80,80,80)" } else { "white" }
      nodes.push(
        @tui.row([
          @tui.text("\{cursor_mark} ", fg="white"),
          if c.read {
            @tui.text("  ", fg="rgb(80,80,80)")
          } else {
            @tui.text("* ", fg="red", bold=true)
          },
          @tui.text("@\{c.author}", fg=author_color),
          @tui.text("  \{c.created_at}  ", fg="rgb(100,100,100)"),
          @tui.text("\"\{preview}\"", fg=body_color),
        ]),
      )
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
