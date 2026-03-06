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
  mut show_read : Bool
  mut my_login : String
}

///|
pub fn AppState::new() -> AppState {
  { comments: [], pull_requests: [], cursor: 0, show_read: true, my_login: "" }
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
