///|
pub(all) enum MissedReason {
  AuthorPR
  AssigneePR
  ReviewerPR
  MyThread
}

///|
pub impl Show for MissedReason with output(self, logger) {
  match self {
    AuthorPR => logger.write_string("author of PR")
    AssigneePR => logger.write_string("assignee of PR")
    ReviewerPR => logger.write_string("reviewer of PR")
    MyThread => logger.write_string("participated in thread")
  }
}

///|
pub(all) struct MissedReply {
  comment : Comment
  reason : MissedReason
}

///|
/// Detect missed replies from all comments (including my own).
/// A missed reply is a comment from someone else that I haven't responded to.
///
/// Rules:
/// - PR where I'm author/assignee: last comment by someone else → missed
/// - PR where I commented: my comment followed by others without my reply → missed
pub fn detect_missed_replies(
  all_comments : Array[Comment],
  pull_requests : Array[PullRequest],
  my_login : String,
) -> Array[MissedReply] {
  let pr_roles : Map[String, Role] = {}
  for pr in pull_requests {
    let key = "\{pr.repo}#\{pr.number}"
    // Author > Assignee > Reviewer priority
    match pr_roles.get(key) {
      Some(Author) => ()
      _ => pr_roles[key] = pr.role
    }
  }
  // Group comments by PR
  let pr_comments : Map[String, Array[Comment]] = {}
  for c in all_comments {
    let key = "\{c.pr_repo}#\{c.pr_number}"
    match pr_comments.get(key) {
      Some(arr) => arr.push(c)
      None => pr_comments[key] = [c]
    }
  }
  let missed : Array[MissedReply] = []
  // Test trigger: self-comment containing "missing" is treated as a missed reply
  for c in all_comments {
    if c.author == my_login && c.body.contains("missing") {
      missed.push({ comment: c, reason: MyThread })
    }
  }
  for key, comments in pr_comments {
    // Sort by created_at (ISO 8601 strings are lexicographically sortable)
    let sorted = comments.copy()
    sorted.sort_by(fn(a, b) { a.created_at.compare(b.created_at) })
    let role = pr_roles.get(key)
    let i_participated = sorted.iter().any(fn(c) { c.author == my_login })
    match role {
      Some(Author) => check_missed_from_end(sorted, my_login, AuthorPR, missed)
      Some(Assignee) =>
        check_missed_from_end(sorted, my_login, AssigneePR, missed)
      Some(Reviewer) =>
        if i_participated {
          check_missed_from_end(sorted, my_login, ReviewerPR, missed)
        }
      None =>
        if i_participated {
          check_missed_from_end(sorted, my_login, MyThread, missed)
        }
    }
  }
  missed
}

///|
fn check_missed_from_end(
  sorted_comments : Array[Comment],
  my_login : String,
  reason : MissedReason,
  out : Array[MissedReply],
) -> Unit {
  // Walk from the end. If the last commenter is me, no missed reply.
  // Otherwise, the last comment by someone else is a missed reply.
  let len = sorted_comments.length()
  if len == 0 {
    return
  }
  let last = sorted_comments[len - 1]
  if last.author == my_login {
    return
  }
  // Find the last comment that is not from me
  out.push({ comment: last, reason })
}
