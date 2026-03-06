///|
async fn main {
  let args = @env.args()
  let repos : Array[String] = []
  for i in 1..<args.length() {
    repos.push(args[i])
  }
  if repos.is_empty() {
    println("Usage: github_noti <owner/repo> [<owner/repo> ...]")
    @sys.exit(1)
  }
  let state = @lib.AppState::new()
  state.my_login = @lib.gh_get_my_login()
  println("Logged in as: \{state.my_login}")
  println("Watching: \{repos}")
  println("Fetching PRs...")
  fetch_all(state, repos)
  let read_ids = @lib.load_read_ids()
  @lib.mark_read_comments(state.comments, read_ids)

  // Setup terminal with mizchi/tui
  let (width, height) = @tui.get_terminal_size()
  let app = @tui.VNodeApp::new(width, height)

  fn render_ui() -> @tui.TuiNode {
    @lib.render_tui(state, width, height)
  }

  @tui.print_raw(@tui.VNodeApp::init_terminal())
  @tui.enable_raw_mode()
  @tui.print_raw(app.render_frame(render_ui()))

  @async.with_task_group(fn(tg) {
    // Background refresh
    tg.spawn_bg(async fn() {
      for {
        @async.sleep(60000)
        let old_count = state.comments.length()
        fetch_all(state, repos)
        let loaded_ids = @lib.load_read_ids()
        @lib.mark_read_comments(state.comments, loaded_ids)
        let new_count = state.comments.length()
        if new_count > old_count {
          let diff = new_count - old_count
          @lib.send_notification("GitHub PR Notifier", "\{diff} new comment(s)")
        }
        @tui.print_raw(app.render_frame(render_ui()))
      }
    })
    // Key input loop
    tg.spawn_bg(async fn() {
      let mut running = true
      while running {
        let key = @tui.read_key()
        if key.length() == 0 {
          continue
        }
        let event = @tui.parse_input(key)
        let mut need_render = true
        match event {
          @tui.InputEvent::Key(key_event) =>
            match key_event {
              @tui.KeyEvent::Char('q', @tui.KeyModifier::None) => {
                let ids = @lib.collect_read_ids(state.comments)
                @lib.save_read_ids(ids)
                running = false
              }
              @tui.KeyEvent::Char('c', @tui.KeyModifier::Ctrl) => {
                let ids = @lib.collect_read_ids(state.comments)
                @lib.save_read_ids(ids)
                running = false
              }
              @tui.KeyEvent::Char('j', _) => {
                let visible = state.visible_comments()
                if state.cursor < visible.length() - 1 {
                  state.cursor = state.cursor + 1
                }
              }
              @tui.KeyEvent::Char('k', _) => {
                if state.cursor > 0 {
                  state.cursor = state.cursor - 1
                }
              }
              @tui.KeyEvent::Special(@tui.SpecialKey::Down, _) => {
                let visible = state.visible_comments()
                if state.cursor < visible.length() - 1 {
                  state.cursor = state.cursor + 1
                }
              }
              @tui.KeyEvent::Special(@tui.SpecialKey::Up, _) => {
                if state.cursor > 0 {
                  state.cursor = state.cursor - 1
                }
              }
              @tui.KeyEvent::Char('r', @tui.KeyModifier::None) => {
                let visible = state.visible_comments()
                if state.cursor < visible.length() {
                  let comment = visible[state.cursor]
                  mark_comment_read(state, comment.id)
                  let ids = @lib.collect_read_ids(state.comments)
                  @lib.save_read_ids(ids)
                }
              }
              @tui.KeyEvent::Char('R', _) => {
                for i in 0..<state.comments.length() {
                  state.comments[i] = { ..state.comments[i], read: true }
                }
                let ids = @lib.collect_read_ids(state.comments)
                @lib.save_read_ids(ids)
              }
              @tui.KeyEvent::Char('o', _) => {
                let visible = state.visible_comments()
                if state.cursor < visible.length() {
                  let comment = visible[state.cursor]
                  let _ = @process.run(
                    "gh",
                    [
                      "pr", "view", "--repo", comment.pr_repo,
                      comment.pr_number.to_string(), "--web",
                    ][:],
                  )
                }
              }
              @tui.KeyEvent::Char('f', _) => {
                state.show_read = not(state.show_read)
                state.cursor = 0
              }
              _ => need_render = false
            }
          _ => need_render = false
        }
        if need_render && running {
          @tui.print_raw(app.render_frame(render_ui()))
        }
      }
      // Cleanup terminal
      @tui.cleanup_stdin()
      @tui.print_raw(@tui.VNodeApp::restore_terminal())
      @sys.exit(0)
    })
  })
}

///|
async fn fetch_all(state : @lib.AppState, repos : Array[String]) -> Unit {
  let all_prs : Array[@lib.PullRequest] = []
  for repo in repos {
    let prs = @lib.gh_list_prs(repo, state.my_login)
    for pr in prs {
      all_prs.push(pr)
    }
  }
  state.pull_requests = all_prs
  let all_comments : Array[@lib.Comment] = []
  for pr in all_prs {
    let comments = @lib.gh_get_comments(
      pr.repo, pr.number, pr.title, pr.url, state.my_login,
    )
    for c in comments {
      all_comments.push(c)
    }
  }
  let old_read : Map[Int64, Bool] = {}
  for c in state.comments {
    if c.read {
      old_read[c.id] = true
    }
  }
  for i in 0..<all_comments.length() {
    if old_read.contains(all_comments[i].id) {
      all_comments[i] = { ..all_comments[i], read: true }
    }
  }
  state.comments = all_comments
  if state.cursor >= all_comments.length() {
    state.cursor = @cmp.maximum(0, all_comments.length() - 1)
  }
}

///|
fn mark_comment_read(state : @lib.AppState, id : Int64) -> Unit {
  for i in 0..<state.comments.length() {
    if state.comments[i].id == id {
      state.comments[i] = { ..state.comments[i], read: true }
    }
  }
}
