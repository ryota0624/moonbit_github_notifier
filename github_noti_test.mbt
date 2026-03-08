// Blackbox tests run against the package's public API. Use `@github_noti` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
fn make_comment(
  id : Int64,
  author : String,
  body : String,
) -> @github_noti.Comment {
  {
    id,
    pr_repo: "owner/repo",
    pr_number: 1,
    pr_title: "test PR",
    pr_url: "https://github.com/owner/repo/pull/1",
    html_url: "https://github.com/owner/repo/pull/1#comment-1",
    author,
    body,
    created_at: "2026-01-01T00:00:00Z",
    read: false,
  }
}

///|
test "load_exclude_patterns: basic patterns" {
  let patterns = @github_noti.load_exclude_patterns("dependabot\n[bot]\ncodecov")
  inspect(patterns.length(), content="3")
  inspect(patterns[0], content="dependabot")
  inspect(patterns[1], content="[bot]")
  inspect(patterns[2], content="codecov")
}

///|
test "load_exclude_patterns: skips comments and empty lines" {
  let patterns = @github_noti.load_exclude_patterns(
    "# this is a comment\ndependabot\n\n  \n[bot]",
  )
  inspect(patterns.length(), content="2")
  inspect(patterns[0], content="dependabot")
  inspect(patterns[1], content="[bot]")
}

///|
test "load_exclude_patterns: trims whitespace" {
  let patterns = @github_noti.load_exclude_patterns("  dependabot  \n\t[bot]\t")
  inspect(patterns.length(), content="2")
  inspect(patterns[0], content="dependabot")
  inspect(patterns[1], content="[bot]")
}

///|
test "load_exclude_patterns: empty input" {
  let patterns = @github_noti.load_exclude_patterns("")
  inspect(patterns.length(), content="0")
}

///|
test "is_comment_excluded: matches author" {
  let c = make_comment(1L, "dependabot[bot]", "bump version")
  inspect(@github_noti.is_comment_excluded(c, ["dependabot"]), content="true")
}

///|
test "is_comment_excluded: matches body" {
  let c = make_comment(1L, "user1", "codecov report: coverage 80%")
  inspect(@github_noti.is_comment_excluded(c, ["codecov"]), content="true")
}

///|
test "is_comment_excluded: no match" {
  let c = make_comment(1L, "user1", "looks good to me")
  inspect(
    @github_noti.is_comment_excluded(c, ["dependabot", "codecov"]),
    content="false",
  )
}

///|
test "is_comment_excluded: empty patterns" {
  let c = make_comment(1L, "user1", "hello")
  inspect(@github_noti.is_comment_excluded(c, []), content="false")
}

///|
test "filter_comments: excludes matching comments" {
  let comments = [
    make_comment(1L, "dependabot[bot]", "bump dep"),
    make_comment(2L, "user1", "looks good"),
    make_comment(3L, "codecov[bot]", "coverage report"),
    make_comment(4L, "user2", "nice work"),
  ]
  let filtered = @github_noti.filter_comments(
    comments,
    ["dependabot", "codecov"],
  )
  inspect(filtered.length(), content="2")
  inspect(filtered[0].id, content="2")
  inspect(filtered[1].id, content="4")
}

///|
test "filter_comments: empty patterns returns all" {
  let comments = [
    make_comment(1L, "dependabot[bot]", "bump dep"),
    make_comment(2L, "user1", "hello"),
  ]
  let filtered = @github_noti.filter_comments(comments, [])
  inspect(filtered.length(), content="2")
}

///|
test "filter_comments: body match excludes comment" {
  let comments = [
    make_comment(1L, "user1", "this mentions dependabot config"),
    make_comment(2L, "user2", "normal comment"),
  ]
  let filtered = @github_noti.filter_comments(comments, ["dependabot"])
  inspect(filtered.length(), content="1")
  inspect(filtered[0].id, content="2")
}

///|
test "filter_comments: all excluded" {
  let comments = [
    make_comment(1L, "bot1", "auto"),
    make_comment(2L, "bot2", "auto"),
  ]
  let filtered = @github_noti.filter_comments(comments, ["bot"])
  inspect(filtered.length(), content="0")
}

///|
test "truncate_body: replaces newlines and tabs with spaces" {
  let result = @github_noti.truncate_body("hello\nworld\tfoo\rbar", 256)
  inspect(result, content="hello world foo bar")
}

///|
test "truncate_body: truncates to max_len with ellipsis" {
  let long = "a".repeat(300)
  let result = @github_noti.truncate_body(long, 256)
  inspect(result.length(), content="256")
  inspect(result.has_suffix("..."), content="true")
}

///|
test "truncate_body: short body unchanged" {
  let result = @github_noti.truncate_body("short", 256)
  inspect(result, content="short")
}
