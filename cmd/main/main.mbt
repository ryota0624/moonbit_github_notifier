///|
async fn main {
  let args = @env.args()
  let repos : Array[String] = []
  let mut use_cmux = false
  let mut dump_file = ""
  let mut load_file = ""
  let mut exclude_file = ""
  let mut interval_sec = 60
  let mut i = 1
  while i < args.length() {
    if args[i] == "--cmux" {
      use_cmux = true
    } else if args[i] == "--dump" && i + 1 < args.length() {
      i += 1
      dump_file = args[i]
    } else if args[i] == "--load" && i + 1 < args.length() {
      i += 1
      load_file = args[i]
    } else if args[i] == "--exclude" && i + 1 < args.length() {
      i += 1
      exclude_file = args[i]
    } else if args[i] == "--interval" && i + 1 < args.length() {
      i += 1
      interval_sec = try { @strconv.parse_int(args[i]) } catch { _ => 60 }
    } else {
      repos.push(args[i])
    }
    i += 1
  }
  let exclude_patterns : Array[String] = if exclude_file.length() > 0 {
    let data = @fs.read_file(exclude_file)
    @lib.load_exclude_patterns(data.text())
  } else {
    []
  }
  let state = @lib.AppState::new()
  if load_file.length() > 0 {
    // Load from file instead of fetching from GitHub
    let data = @fs.read_file(load_file)
    @lib.load_state_from_json(data.text(), state)
    state.comments = @lib.filter_comments(state.comments, exclude_patterns)
    println("Loaded \{state.comments.length()} comments from \{load_file}")
  } else {
    if repos.is_empty() {
      println(
        "Usage: github_noti [--cmux] [--dump <file>] [--load <file>] [--exclude <file>] <owner/repo> [...]",
      )
      @sys.exit(1)
    }
    state.my_login = @lib.gh_get_my_login()
    println("Logged in as: \{state.my_login}")
    println("Watching: \{repos}")
    println("Fetching PRs...")
    fetch_all(state, repos, exclude_patterns)
    if dump_file.length() > 0 {
      @fs.write_file(dump_file, @lib.dump_state_json(state))
      println("Dumped state to \{dump_file}")
    }
  }
  let read_ids = @lib.load_read_ids()
  @lib.mark_read_comments(state.comments, read_ids)

  // Setup terminal with mizchi/tui
  let (init_w, init_h) = @tui.get_terminal_size()
  let cur_width : Ref[Int] = { val: init_w }
  let cur_height : Ref[Int] = { val: init_h }
  let app = @tui.VNodeApp::new(init_w, init_h)

  fn render_ui() -> @tui.TuiNode {
    @lib.render_tui(state, cur_width.val, cur_height.val)
  }

  @tui.print_raw(@tui.VNodeApp::init_terminal())
  @tui.enable_raw_mode()
  @tui.print_raw(app.render_frame(render_ui()))

  // Listen for terminal resize
  @tui_io.start_resize_listener(fn(w, h) {
    cur_width.val = w
    cur_height.val = h
    app.resize(w, h)
    @tui.print_raw(app.render_frame(render_ui()))
  })

  @async.with_task_group(fn(tg) {
    // Background refresh
    tg.spawn_bg(async fn() {
      for {
        @async.sleep(interval_sec * 1000)
        let old_ids : Map[Int64, Bool] = {}
        for c in state.comments {
          old_ids[c.id] = true
        }
        fetch_all(state, repos, exclude_patterns)
        let loaded_ids = @lib.load_read_ids()
        @lib.mark_read_comments(state.comments, loaded_ids)
        for c in state.comments {
          if not(old_ids.contains(c.id)) {
            let title = "\{c.pr_repo}#\{c.pr_number} @\{c.author}"
            let body = c.body
            if use_cmux {
              @lib.send_notification_cmux(title, body)
            } else {
              @lib.send_notification_osascript(title, body)
            }
          }
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
              @tui.KeyEvent::Char('k', _) =>
                if state.cursor > 0 {
                  state.cursor = state.cursor - 1
                }
              @tui.KeyEvent::Special(@tui.SpecialKey::Down, _) => {
                let visible = state.visible_comments()
                if state.cursor < visible.length() - 1 {
                  state.cursor = state.cursor + 1
                }
              }
              @tui.KeyEvent::Special(@tui.SpecialKey::Up, _) =>
                if state.cursor > 0 {
                  state.cursor = state.cursor - 1
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
                      "pr",
                      "view",
                      "--repo",
                      comment.pr_repo,
                      comment.pr_number.to_string(),
                      "--web",
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
async fn fetch_all(
  state : @lib.AppState,
  repos : Array[String],
  exclude_patterns : Array[String],
) -> Unit {
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
      pr.repo,
      pr.number,
      pr.title,
      pr.url,
      state.my_login,
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
  let filtered = @lib.filter_comments(all_comments, exclude_patterns)
  state.comments = filtered
  if state.cursor >= filtered.length() {
    state.cursor = @cmp.maximum(0, filtered.length() - 1)
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
