///|
pub async fn gh_exec(args : Array[String]) -> String {
  let (code, stdout) = @process.collect_stdout("gh", args[:])
  let text = stdout.text()
  if code != 0 {
    raise GhError("gh command failed with exit code \{code}")
  }
  text
}

///|
pub suberror GhError {
  GhError(String)
}

///|
pub async fn gh_api(endpoint : String) -> Json {
  let text = gh_exec(["api", endpoint])
  @json.parse(text)
}

///|
pub async fn gh_get_my_login() -> String {
  let text = gh_exec(["api", "user", "--jq", ".login"])
  text.trim_end().to_string()
}

///|
pub async fn gh_list_prs(repo : String, login : String) -> Array[PullRequest] {
  let prs : Array[PullRequest] = []
  let author_json = gh_exec([
    "pr", "list", "--repo", repo, "--author", login, "--state", "open", "--json",
    "number,title,url",
  ])
  parse_pr_list(author_json, repo, Author, prs)
  let assignee_json = gh_exec([
    "pr", "list", "--repo", repo, "--assignee", login, "--state", "open", "--json",
    "number,title,url",
  ])
  parse_pr_list(assignee_json, repo, Assignee, prs)
  let reviewer_json = gh_exec([
    "pr",
    "list",
    "--repo",
    repo,
    "--search",
    "review-requested:\{login}",
    "--state",
    "open",
    "--json",
    "number,title,url",
  ])
  parse_pr_list(reviewer_json, repo, Reviewer, prs)
  dedup_prs(prs)
}

///|
fn parse_pr_list(
  json_text : String,
  repo : String,
  role : Role,
  out : Array[PullRequest],
) -> Unit raise {
  let json = @json.parse(json_text)
  match json {
    Array(items) =>
      for item in items {
        match item {
          Object(obj) => {
            let number = match obj.get("number") {
              Some(Number(n, ..)) => n.to_int()
              _ => continue
            }
            let title = match obj.get("title") {
              Some(String(s)) => s
              _ => ""
            }
            let url = match obj.get("url") {
              Some(String(s)) => s
              _ => ""
            }
            out.push({ repo, number, title, url, role })
          }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn dedup_prs(prs : Array[PullRequest]) -> Array[PullRequest] {
  let seen : Map[String, Bool] = {}
  let result : Array[PullRequest] = []
  for pr in prs {
    let key = "\{pr.repo}#\{pr.number}"
    if not(seen.contains(key)) {
      seen[key] = true
      result.push(pr)
    }
  }
  result
}

///|
pub async fn gh_get_comments(
  repo : String,
  pr_number : Int,
  pr_title : String,
  pr_url : String,
  my_login : String,
) -> Array[Comment] {
  let comments : Array[Comment] = []
  let review_json = gh_api("repos/\{repo}/pulls/\{pr_number}/comments")
  parse_comments(
    review_json, repo, pr_number, pr_title, pr_url, my_login, comments,
  )
  let issue_json = gh_api("repos/\{repo}/issues/\{pr_number}/comments")
  parse_comments(
    issue_json, repo, pr_number, pr_title, pr_url, my_login, comments,
  )
  comments
}

///|
pub async fn gh_get_all_comments(
  repo : String,
  pr_number : Int,
  pr_title : String,
  pr_url : String,
) -> Array[Comment] {
  let comments : Array[Comment] = []
  let review_json = gh_api("repos/\{repo}/pulls/\{pr_number}/comments")
  parse_all_comments(review_json, repo, pr_number, pr_title, pr_url, comments)
  let issue_json = gh_api("repos/\{repo}/issues/\{pr_number}/comments")
  parse_all_comments(issue_json, repo, pr_number, pr_title, pr_url, comments)
  comments
}

///|
fn parse_all_comments(
  json : Json,
  pr_repo : String,
  pr_number : Int,
  pr_title : String,
  pr_url : String,
  out : Array[Comment],
) -> Unit {
  match json {
    Array(items) =>
      for item in items {
        match item {
          Object(obj) => {
            let author = match obj.get("user") {
              Some(Object(user)) =>
                match user.get("login") {
                  Some(String(s)) => s
                  _ => continue
                }
              _ => continue
            }
            let id : Int64 = match obj.get("id") {
              Some(Number(n, ..)) => n.to_int64()
              _ => continue
            }
            let body = match obj.get("body") {
              Some(String(s)) => s
              _ => ""
            }
            let created_at = match obj.get("created_at") {
              Some(String(s)) => s
              _ => ""
            }
            out.push({
              id,
              pr_repo,
              pr_number,
              pr_title,
              pr_url,
              author,
              body,
              created_at,
              read: false,
            })
          }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn parse_comments(
  json : Json,
  pr_repo : String,
  pr_number : Int,
  pr_title : String,
  pr_url : String,
  my_login : String,
  out : Array[Comment],
) -> Unit {
  match json {
    Array(items) =>
      for item in items {
        match item {
          Object(obj) => {
            let author = match obj.get("user") {
              Some(Object(user)) =>
                match user.get("login") {
                  Some(String(s)) => s
                  _ => continue
                }
              _ => continue
            }
            if author == my_login {
              continue
            }
            let id : Int64 = match obj.get("id") {
              Some(Number(n, ..)) => n.to_int64()
              _ => continue
            }
            let body = match obj.get("body") {
              Some(String(s)) => s
              _ => ""
            }
            let created_at = match obj.get("created_at") {
              Some(String(s)) => s
              _ => ""
            }
            out.push({
              id,
              pr_repo,
              pr_number,
              pr_title,
              pr_url,
              author,
              body,
              created_at,
              read: false,
            })
          }
          _ => ()
        }
      }
    _ => ()
  }
}
