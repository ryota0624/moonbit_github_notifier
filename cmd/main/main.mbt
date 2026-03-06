///|
let esc : String = "\u001b"

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
  print_render(state)
  @async.with_task_group(fn(tg) {
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
        print_render(state)
      }
    })
    tg.spawn_bg(async fn() { key_loop(state) })
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
  state.comments = all_comments
  if state.cursor >= all_comments.length() {
    state.cursor = @cmp.maximum(0, all_comments.length() - 1)
  }
}

///|
async fn key_loop(state : @lib.AppState) -> Unit {
  let buf : FixedArray[Byte] = FixedArray::make(4, b'\x00')
  for {
    let n = @stdio.stdin.read(buf)
    if n <= 0 {
      continue
    }
    let ch = buf[0]
    match ch {
      b'q' => {
        let ids = @lib.collect_read_ids(state.comments)
        @lib.save_read_ids(ids)
        println("\{esc}[2J\{esc}[H")
        @sys.exit(0)
      }
      b'j' => {
        let visible = state.visible_comments()
        if state.cursor < visible.length() - 1 {
          state.cursor = state.cursor + 1
        }
        print_render(state)
      }
      b'k' => {
        if state.cursor > 0 {
          state.cursor = state.cursor - 1
        }
        print_render(state)
      }
      b'r' => {
        let visible = state.visible_comments()
        if state.cursor < visible.length() {
          let comment = visible[state.cursor]
          mark_comment_read(state, comment.id)
          let ids = @lib.collect_read_ids(state.comments)
          @lib.save_read_ids(ids)
          print_render(state)
        }
      }
      b'R' => {
        for i in 0..<state.comments.length() {
          state.comments[i] = { ..state.comments[i], read: true }
        }
        let ids = @lib.collect_read_ids(state.comments)
        @lib.save_read_ids(ids)
        print_render(state)
      }
      b'o' => {
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
      b'f' => {
        state.show_read = not(state.show_read)
        state.cursor = 0
        print_render(state)
      }
      _ => ()
    }
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

///|
fn print_render(state : @lib.AppState) -> Unit raise {
  println(@lib.render(state))
}
