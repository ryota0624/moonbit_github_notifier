///|
let state_dir : String = "~/.config/github_noti"

///|
fn expand_home(path : String) -> String raise {
  match @sys.get_env_var("HOME") {
    Some(home) =>
      if path.has_prefix("~/") {
        home + path[1:].to_string()
      } else {
        path
      }
    None => path
  }
}

///|
pub async fn ensure_state_dir() -> Unit {
  let dir = expand_home(state_dir)
  let exists = @fs.exists(dir)
  if not(exists) {
    @fs.mkdir(dir, permission=0o755, recursive=true)
  }
}

///|
pub async fn save_read_ids(read_ids : Array[Int64]) -> Unit {
  ensure_state_dir()
  let path = expand_home(state_dir + "/read_ids.json")
  let arr : Array[Json] = read_ids.map(fn(id) { Json::number(id.to_double()) })
  let json = Json::array(arr)
  @fs.write_file(path, json.stringify())
}

///|
pub async fn load_read_ids() -> Array[Int64] {
  let path = expand_home(state_dir + "/read_ids.json")
  let exists = @fs.exists(path)
  if not(exists) {
    return []
  }
  let data = @fs.read_file(path)
  let text = data.text()
  let json = @json.parse(text)
  let ids : Array[Int64] = []
  match json {
    Array(items) =>
      for item in items {
        match item {
          Number(n, ..) => ids.push(n.to_int64())
          _ => ()
        }
      }
    _ => ()
  }
  ids
}

///|
pub fn mark_read_comments(
  comments : Array[Comment],
  read_ids : Array[Int64],
) -> Unit {
  let id_set : Map[Int64, Bool] = {}
  for id in read_ids {
    id_set[id] = true
  }
  for i in 0..<comments.length() {
    if id_set.contains(comments[i].id) {
      comments[i] = { ..comments[i], read: true }
    }
  }
}

///|
pub fn collect_read_ids(comments : Array[Comment]) -> Array[Int64] {
  let ids : Array[Int64] = []
  for c in comments {
    if c.read {
      ids.push(c.id)
    }
  }
  ids
}
