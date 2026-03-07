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
  let state = @lib.AppState::new()
  if load_file.length() > 0 {
    let data = @fs.read_file(load_file)
    @lib.load_state_from_json(data.text(), state)
    state.comments = @lib.filter_comments(state.comments, exclude_patterns)
    println("Loaded \{state.comments.length()} comments from \{load_file}")
  } else {
    if repos.is_empty() {
      println(
        "Usage: github_noti [--cmux] [--dump <file>] [--load <file>] [--exclude <file>] [--interval <sec>] <owner/repo> [...]",
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
  run_watch(state, repos, exclude_patterns, use_cmux, interval_sec)
}

///|
async fn run_watch(
  state : @lib.AppState,
  repos : Array[String],
  exclude_patterns : Array[String],
  use_cmux : Bool,
  interval_sec : Int,
) -> Unit {
  println("Watching for new comments (interval: \{interval_sec}s)...")
  let notified_missed_ids : Map[Int64, Bool] = {}
  for c in state.comments {
    if not(c.read) {
      println("\{c.pr_repo}#\{c.pr_number} @\{c.author}")
    }
  }
  check_and_notify_missed(state, use_cmux, notified_missed_ids)
  for {
    @async.sleep(interval_sec * 1000)
    let old_ids : Map[Int64, Bool] = {}
    for c in state.comments {
      old_ids[c.id] = true
    }
    fetch_all(state, repos, exclude_patterns)
    let debug = match @sys.get_env_var("DEBUG") {
      Some("true") | Some("1") => true
      _ => false
    }
    if debug {
      println("[DEBUG] polled \{state.comments.length()} comments")
    }
    let loaded_ids = @lib.load_read_ids()
    @lib.mark_read_comments(state.comments, loaded_ids)
    for c in state.comments {
      if not(old_ids.contains(c.id)) {
        println(
          "new comment: \{c.pr_repo}#\{c.pr_number} @\{c.author}: \{c.notifiable_comment()}",
        )
        let title = "\{c.pr_repo}#\{c.pr_number} @\{c.author}"
        if use_cmux {
          @lib.send_notification_cmux(title, c.notifiable_comment())
        } else {
          @lib.send_notification_osascript(title, c.notifiable_comment())
        }
      } else if debug {
        println(
          "[DEBUG] skipped (known): \{c.pr_repo}#\{c.pr_number} @\{c.author}: \{c.notifiable_comment()}",
        )
      }
    }
    check_and_notify_missed(state, use_cmux, notified_missed_ids)
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
async fn check_and_notify_missed(
  state : @lib.AppState,
  use_cmux : Bool,
  notified_missed_ids : Map[Int64, Bool],
) -> Unit {
  let all_comments = fetch_all_comments_for_missed(state)
  let missed = @lib.detect_missed_replies(
    all_comments,
    state.pull_requests,
    state.my_login,
  )
  let debug = match @sys.get_env_var("DEBUG") {
    Some("true") | Some("1") => true
    _ => false
  }
  for m in missed {
    let c = m.comment
    if notified_missed_ids.contains(c.id) {
      if debug {
        println(
          "[DEBUG] skipped (already notified): \{c.pr_repo}#\{c.pr_number} @\{c.author}:\n ● \{c.notifiable_comment()}",
        )
      }
      continue
    }
    notified_missed_ids[c.id] = true
    if debug {
      println(
        "[DEBUG] missed reply (\{m.reason}): \{c.pr_repo}#\{c.pr_number} @\{c.author}:\n ● \{c.notifiable_comment()}",
      )
    }
    let title = "Reply needed: \{c.pr_repo}#\{c.pr_number}"
    let body = "@\{c.author}: \{c.notifiable_comment()}"
    if use_cmux {
      @lib.send_notification_cmux(title, body)
    } else {
      @lib.send_notification_osascript(title, body)
    }
  }
}
