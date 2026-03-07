///|
fn make_comment(
  id : Int64,
  author : String,
  pr_repo : String,
  pr_number : Int,
  created_at : String,
) -> Comment {
  {
    id,
    pr_repo,
    pr_number,
    pr_title: "test PR",
    pr_url: "",
    author,
    body: "comment by \{author}",
    created_at,
    read: false,
  }
}

///|
test "missed reply: author PR, last comment by other" {
  let comments = [
    make_comment(1L, "me", "org/repo", 1, "2024-01-01T00:00:00Z"),
    make_comment(2L, "alice", "org/repo", 1, "2024-01-02T00:00:00Z"),
  ]
  let prs = [
    { repo: "org/repo", number: 1, title: "test", url: "", role: Author },
  ]
  let missed = detect_missed_replies(comments, prs, "me")
  inspect(missed.length(), content="1")
  inspect(missed[0].comment.id, content="2")
  inspect(missed[0].reason, content="author of PR")
}

///|
test "missed reply: author PR, last comment by me" {
  let comments = [
    make_comment(1L, "alice", "org/repo", 1, "2024-01-01T00:00:00Z"),
    make_comment(2L, "me", "org/repo", 1, "2024-01-02T00:00:00Z"),
  ]
  let prs = [
    { repo: "org/repo", number: 1, title: "test", url: "", role: Author },
  ]
  let missed = detect_missed_replies(comments, prs, "me")
  inspect(missed.length(), content="0")
}

///|
test "missed reply: assignee PR" {
  let comments = [
    make_comment(1L, "bob", "org/repo", 2, "2024-01-01T00:00:00Z"),
  ]
  let prs = [
    { repo: "org/repo", number: 2, title: "test", url: "", role: Assignee },
  ]
  let missed = detect_missed_replies(comments, prs, "me")
  inspect(missed.length(), content="1")
  inspect(missed[0].reason, content="assignee of PR")
}

///|
test "missed reply: participated thread" {
  let comments = [
    make_comment(1L, "alice", "org/repo", 3, "2024-01-01T00:00:00Z"),
    make_comment(2L, "me", "org/repo", 3, "2024-01-02T00:00:00Z"),
    make_comment(3L, "alice", "org/repo", 3, "2024-01-03T00:00:00Z"),
  ]
  let prs = [
    { repo: "org/repo", number: 3, title: "test", url: "", role: Reviewer },
  ]
  let missed = detect_missed_replies(comments, prs, "me")
  inspect(missed.length(), content="1")
  inspect(missed[0].comment.id, content="3")
  inspect(missed[0].reason, content="reviewer of PR")
}

///|
test "missed reply: reviewer but never commented, no missed" {
  let comments = [
    make_comment(1L, "alice", "org/repo", 4, "2024-01-01T00:00:00Z"),
  ]
  let prs = [
    { repo: "org/repo", number: 4, title: "test", url: "", role: Reviewer },
  ]
  let missed = detect_missed_replies(comments, prs, "me")
  inspect(missed.length(), content="0")
}

///|
test "missed reply: self-comment with 'missing' triggers test notification" {
  let comments : Array[Comment] = [
    {
      ..make_comment(1L, "me", "org/repo", 5, "2024-01-01T00:00:00Z"),
      body: "missing",
    },
  ]
  let prs = [
    { repo: "org/repo", number: 5, title: "test", url: "", role: Author },
  ]
  let missed = detect_missed_replies(comments, prs, "me")
  inspect(missed.length(), content="1")
  inspect(missed[0].comment.author, content="me")
}
