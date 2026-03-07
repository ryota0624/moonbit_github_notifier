///|
pub(all) struct PullRequest {
  repo : String
  number : Int
  title : String
  url : String
  role : Role
}

///|
pub(all) enum Role {
  Author
  Reviewer
  Assignee
}

///|
pub impl Show for Role with output(self, logger) {
  match self {
    Author => logger.write_string("author")
    Reviewer => logger.write_string("reviewer")
    Assignee => logger.write_string("assignee")
  }
}

///|
pub(all) struct Comment {
  id : Int64
  pr_repo : String
  pr_number : Int
  pr_title : String
  pr_url : String
  author : String
  body : String
  created_at : String
  read : Bool
}

///|
pub(all) struct AppState {
  mut comments : Array[Comment]
  mut pull_requests : Array[PullRequest]
  mut cursor : Int
  mut scroll_offset : Int
  mut show_read : Bool
  mut my_login : String
}

///|
pub fn AppState::new() -> AppState {
  {
    comments: [],
    pull_requests: [],
    cursor: 0,
    scroll_offset: 0,
    show_read: true,
    my_login: "",
  }
}

///|
pub fn AppState::adjust_scroll(self : AppState, visible_height : Int) -> Unit {
  if self.cursor < self.scroll_offset {
    self.scroll_offset = self.cursor
  }
  if self.cursor >= self.scroll_offset + visible_height {
    self.scroll_offset = self.cursor - visible_height + 1
  }
}

///|
pub fn AppState::visible_comments(self : AppState) -> Array[Comment] {
  if self.show_read {
    self.comments
  } else {
    self.comments.filter(fn(c) { not(c.read) })
  }
}

///|
pub fn AppState::unread_count(self : AppState) -> Int {
  self.comments.fold(init=0, fn(acc, c) { if c.read { acc } else { acc + 1 } })
}

///|
pub fn comment_to_json(c : Comment) -> Json {
  {
    "id": c.id.to_double(),
    "pr_repo": c.pr_repo,
    "pr_number": c.pr_number.to_double(),
    "pr_title": c.pr_title,
    "pr_url": c.pr_url,
    "author": c.author,
    "body": c.body,
    "created_at": c.created_at,
    "read": c.read,
  }
}

///|
pub fn comment_from_json(json : Json) -> Comment? {
  match json {
    {
      "id": Number(id, ..),
      "pr_repo": String(pr_repo),
      "pr_number": Number(pr_number, ..),
      "pr_title": String(pr_title),
      "pr_url": String(pr_url),
      "author": String(author),
      "body": String(body),
      "created_at": String(created_at),
      ..
    } => {
      let read = match json {
        { "read": True, .. } => true
        _ => false
      }
      Some(
        {
          id: id.to_int64(),
          pr_repo,
          pr_number: pr_number.to_int(),
          pr_title,
          pr_url,
          author,
          body,
          created_at,
          read,
        },
      )
    }
    _ => None
  }
}

///|
pub fn pr_to_json(pr : PullRequest) -> Json {
  {
    "repo": pr.repo,
    "number": pr.number.to_double(),
    "title": pr.title,
    "url": pr.url,
    "role": match pr.role {
      Author => "author"
      Reviewer => "reviewer"
      Assignee => "assignee"
    },
  }
}

///|
pub fn pr_from_json(json : Json) -> PullRequest? {
  match json {
    {
      "repo": String(repo),
      "number": Number(number, ..),
      "title": String(title),
      "url": String(url),
      "role": String(role_str),
      ..
    } => {
      let role = match role_str {
        "reviewer" => Reviewer
        "assignee" => Assignee
        _ => Author
      }
      Some({ repo, number: number.to_int(), title, url, role })
    }
    _ => None
  }
}

///|
pub fn dump_state_json(state : AppState) -> String {
  let obj : Json = {
    "my_login": state.my_login,
    "pull_requests": Json::array(state.pull_requests.map(pr_to_json)),
    "comments": Json::array(state.comments.map(comment_to_json)),
  }
  obj.stringify()
}

///|
pub fn load_exclude_patterns(text : String) -> Array[String] {
  let patterns : Array[String] = []
  for line in text.split("\n") {
    let trimmed = line.trim(chars=" \t\r").to_string()
    if trimmed.length() > 0 && not(trimmed.has_prefix("#")) {
      patterns.push(trimmed)
    }
  }
  patterns
}

///|
pub fn is_comment_excluded(
  c : Comment,
  patterns : Array[String],
) -> Bool {
  for p in patterns {
    if c.author.contains(p) || c.body.contains(p) {
      return true
    }
  }
  false
}

///|
pub fn filter_comments(
  comments : Array[Comment],
  patterns : Array[String],
) -> Array[Comment] {
  if patterns.is_empty() {
    return comments
  }
  comments.filter(fn(c) { not(is_comment_excluded(c, patterns)) })
}

///|
pub fn load_state_from_json(text : String, state : AppState) -> Unit {
  let json = try {
    @json.parse(text)
  } catch {
    _ => return
  }
  match json {
    { "my_login": String(login), .. } => state.my_login = login
    _ => ()
  }
  match json {
    { "pull_requests": Array(prs), .. } =>
      state.pull_requests = prs.filter_map(pr_from_json)
    _ => ()
  }
  match json {
    { "comments": Array(comments), .. } =>
      state.comments = comments.filter_map(comment_from_json)
    _ => ()
  }
}
