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
      interval_sec = @strconv.parse_int(args[i]) catch { _ => 60 }
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
  println("exclude patterns: \{exclude_patterns}")
  let state = @lib.AppState::new()
  if load_file.length() > 0 {
    let data = @fs.read_file(load_file)
    @lib.load_state_from_json(data.text(), state)
    state.comments = @lib.filter_comments(state.comments, exclude_patterns)
    log_info("loaded \{state.comments.length()} comments from \{load_file}")
  } else {
    if repos.is_empty() {
      println(
        "Usage: github_noti [--cmux] [--dump <file>] [--load <file>] [--exclude <file>] [--interval <sec>] <owner/repo> [...]",
      )
      @sys.exit(1)
    }
    state.my_login = @lib.gh_get_my_login()
    log_info("logged in as \{state.my_login}")
    log_info("watching \{repos}")
    log_info("fetching PRs...")
    fetch_all(state, repos, exclude_patterns)
    if dump_file.length() > 0 {
      @fs.write_file(dump_file, @lib.dump_state_json(state))
      log_info("dumped state to \{dump_file}")
    }
  }
  let read_ids = @lib.load_read_ids()
  @lib.mark_read_comments(state.comments, read_ids)
  run_watch(state, repos, exclude_patterns, use_cmux, interval_sec)
}

///|
fn is_debug() -> Bool {
  match @sys.get_env_var("DEBUG") {
    Some("true") | Some("1") => true
    _ => false
  }
}

///|
fn log_info(msg : String) -> Unit {
  println("[info] \{msg}")
}

///|
fn log_debug(msg : String) -> Unit {
  if is_debug() {
    println("[debug] \{msg}")
  }
}

///|
fn log_event_block(
  new_comments : Array[@lib.Comment],
  missed : Array[@lib.MissedReply],
) -> Unit {
  let total = new_comments.length() + missed.length()
  if total == 0 {
    return
  }
  println("--- \{total} updates ---")
  for c in new_comments {
    println("  [new_comment] \{c.pr_repo}#\{c.pr_number} @\{c.author}")
    println("    \{c.notifiable_comment()}")
    println("    \u001b[32m\{c.html_url}\u001b[0m")
  }
  for m in missed {
    let c = m.comment
    println("  [reply_needed] \{c.pr_repo}#\{c.pr_number} @\{c.author}")
    println("    \{c.notifiable_comment()}")
    println("    \u001b[32m\{c.html_url}\u001b[0m")
  }
  println("---")
}

///|
async fn run_watch(
  state : @lib.AppState,
  repos : Array[String],
  exclude_patterns : Array[String],
  use_cmux : Bool,
  interval_sec : Int,
) -> Unit {
  log_info("watching (interval: \{interval_sec}s)")
  let notified_missed_ids : Map[Int64, Bool] = {}
  let unread : Array[@lib.Comment] = []
  for c in state.comments {
    if not(c.read) {
      unread.push(c)
    }
  }
  let initial_missed = collect_missed(state, notified_missed_ids, exclude_patterns)
  log_event_block(unread, initial_missed)
  send_notification(unread, initial_missed, use_cmux)
  for {
    @async.sleep(interval_sec * 1000)
    let old_ids : Map[Int64, Bool] = {}
    for c in state.comments {
      old_ids[c.id] = true
    }
    fetch_all(state, repos, exclude_patterns)
    log_debug("polled \{state.comments.length()} comments")
    let loaded_ids = @lib.load_read_ids()
    @lib.mark_read_comments(state.comments, loaded_ids)
    let new_items : Array[@lib.Comment] = []
    for c in state.comments {
      if not(old_ids.contains(c.id)) {
        new_items.push(c)
      } else {
        log_debug("skipped (known): \{c.pr_repo}#\{c.pr_number} @\{c.author}")
      }
    }
    let missed_items = collect_missed(state, notified_missed_ids, exclude_patterns)
    log_event_block(new_items, missed_items)
    send_notification(new_items, missed_items, use_cmux)
  }
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
}

///|
async fn fetch_all_comments_for_missed(
  state : @lib.AppState,
) -> Array[@lib.Comment] {
  let all : Array[@lib.Comment] = []
  for pr in state.pull_requests {
    let comments = @lib.gh_get_all_comments(
      pr.repo,
      pr.number,
      pr.title,
      pr.url,
    )
    for c in comments {
      all.push(c)
    }
  }
  all
}

///|
async fn collect_missed(
  state : @lib.AppState,
  notified_missed_ids : Map[Int64, Bool],
  exclude_patterns : Array[String],
) -> Array[@lib.MissedReply] {
  let all_comments = fetch_all_comments_for_missed(state)
  let filtered_comments = @lib.filter_comments(all_comments, exclude_patterns)
  let missed = @lib.detect_missed_replies(
    filtered_comments,
    state.pull_requests,
    state.my_login,
  )
  let result : Array[@lib.MissedReply] = []
  for m in missed {
    let c = m.comment
    if notified_missed_ids.contains(c.id) {
      log_debug(
        "skipped (already notified): \{c.pr_repo}#\{c.pr_number} @\{c.author}",
      )
      continue
    }
    notified_missed_ids[c.id] = true
    result.push(m)
  }
  result
}

///|
async fn send_notification(
  new_comments : Array[@lib.Comment],
  missed : Array[@lib.MissedReply],
  use_cmux : Bool,
) -> Unit {
  if new_comments.length() == 0 && missed.length() == 0 {
    return
  }
  let lines : Array[String] = []
  for c in new_comments {
    lines.push(
      "\{c.pr_repo}#\{c.pr_number} @\{c.author}: \{c.notifiable_comment()}\n  \{c.html_url}",
    )
  }
  for m in missed {
    let c = m.comment
    lines.push(
      "[reply needed] \{c.pr_repo}#\{c.pr_number} @\{c.author}: \{c.notifiable_comment()}\n  \{c.html_url}",
    )
  }
  let total = new_comments.length() + missed.length()
  let title = "github_noti: \{total} new"
  let body = lines.join("\n")
  if use_cmux {
    @lib.send_notification_cmux(title, body)
  } else {
    @lib.send_notification_osascript(title, body)
  }
}
