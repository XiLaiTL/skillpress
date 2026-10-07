///|
/// **静态服务**（进程内）—— 把站点实例的 dist/ 喂给浏览器。
///
/// ⚠️ 与旧实现的分工差别：lib/verify-site.mjs 是**再 spawn 一个 node serve-web.mjs**，
///    这里是**同一个进程里**起 —— 少一个 Node 子进程，也少一个「服务是别人的」的歧义。
///
/// ⚠️ 两个口径照抄旧实现：① 路径里的 `..` 一律挡掉（伺服的是整个 dist）；
///    ② 起完服务要**自证**「真的是我在应答」，不能只看「起来了」
///    （旧实现实测踩过「测到碰巧同端口的别人」）。
/// 扩展名 → Content-Type（只列站点真的会用到的那几种；认不出给 octet-stream）。
fn content_type(path : String) -> String {
  if path.has_suffix(".html") {
    "text/html; charset=utf-8"
  } else if path.has_suffix(".js") {
    "text/javascript; charset=utf-8"
  } else if path.has_suffix(".css") {
    "text/css; charset=utf-8"
  } else if path.has_suffix(".json") {
    "application/json; charset=utf-8"
  } else if path.has_suffix(".png") {
    "image/png"
  } else if path.has_suffix(".svg") {
    "image/svg+xml"
  } else {
    "application/octet-stream"
  }
}

///|
/// URL 路径 → 盘上的文件路径。
///
/// ⚠️ 挡掉 `..`：这里伺服的是**整个 dist 目录**，不挡的话一个 `../../..` 就能把仓库读走。
///    探针阶段也照挡 —— "先能跑、以后再补安全"这种话，补的那次永远不来。
fn resolve_url(dist : String, url_path : String) -> String? {
  let clean = if url_path == "" || url_path == "/" { "index.html" } else { url_path }
  if clean.contains("..") {
    return None
  }
  let rel : String = if clean.has_prefix("/") { clean[1:].to_owned() } else { clean }
  if rel.has_suffix("/") {
    return Some(@gates.join_path(dist, rel + "index.html"))
  }
  Some(@gates.join_path(dist, rel))
}

///|
/// 一次静态请求的应答。
async fn serve_one(conn : @http.ServerConnection, dist : String, url_path : String) -> Unit {
  match resolve_url(dist, url_path) {
    None => conn.send_response(404, "NotFound")
    Some(file) =>
      if !@fs.exists(file) {
        conn.send_response(404, "NotFound")
      } else {
        let f = @fs.open(file, mode=ReadOnly)
        defer f.close()
        conn
        ..send_response(200, "OK", extra_headers={
          "Content-Type": content_type(file),
          "Content-Length": f.size().to_string(),
        })
        ..write_reader(f)
        .end_response()
      }
  }
}

///|
