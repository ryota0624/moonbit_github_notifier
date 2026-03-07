///|
test "render_tui layout snapshot" {
  let state = AppState::new()
  state.comments = [
    {
      id: 1L,
      pr_repo: "owner/repo",
      pr_number: 1,
      pr_title: "Fix bug",
      pr_url: "https://example.com",
      author: "alice",
      body: "looks good",
      created_at: "2025-01-01",
      read: false,
    },
    {
      id: 2L,
      pr_repo: "owner/repo",
      pr_number: 1,
      pr_title: "Fix bug",
      pr_url: "https://example.com",
      author: "bob",
      body: "needs fix",
      created_at: "2025-01-02",
      read: true,
    },
  ]
  let node = render_tui(state, 60, 15)
  let output = @tui.render_vnode_once(60, 15, node)
  inspect!(output, content=(
    #|[2J[1;1H[38;5;51m╭──────────────────────────────────────────────────────────╮[2;1H│[38;5;231m                                                          [38;5;51m│[3;1H│[38;5;231m [1m[38;5;226mGitHub PR Notifier[0m[38;5;231m                     [38;5;51m[1 unread][38;5;231m  [38;5;244m[all][38;5;231m [38;5;51m│[4;1H│[38;5;231m                                                          [38;5;51m│[5;1H│[38;5;231m                                                          [38;5;51m│[6;1H│[38;5;231m                                                          [38;5;51m│[7;1H│[1mowner/repo[0m[38;5;226m #1 [1m[38;5;231mFix bug[0m[38;5;231m                                     [38;5;51m│[8;1H│[38;5;231m                                                          [38;5;51m│[9;1H│[38;5;231m                                                          [38;5;51m│[10;1H│[1m[38;5;226m[48;5;59m> [38;5;196m* [38;5;51m@alice[0m[38;5;249m[48;5;59m  2025-01-01  [1m[38;5;231m"looks good"[0m[38;5;231m[48;5;59m                     [49m [38;5;51m│[11;1H│[38;5;231m[48;5;59m                                                         [49m [38;5;51m│[12;1H│[38;5;231m  [38;5;239m  [38;5;241m@bob  2025-01-02  [38;5;239m"needs fix"[38;5;231m                         [38;5;51m│[13;1H│[38;5;231m                                                          [38;5;51m│[14;1H│[38;5;231m                                                          [38;5;51m│[15;1H╰──────────────────────────────────────────────────────────╯[0m

  ))
}
