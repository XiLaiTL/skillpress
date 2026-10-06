///|
/// 一份**够用就好**的 JSON 读取器（只服务锁文件）。
///
/// 为什么不直接用 core 的 `@json`：**键的顺序**。
/// 旧实现是 `JSON.parse` + `Object.keys(lock.skills)`，而 JS 对象**保留键的插入顺序** ——
/// "锁里还有已删除的 skill"那条提示是按这个顺序打的。core 的 `Json::Object` 是 `Map`，
/// 拿不回顺序 ⇒ G8 的输出可能对不上。所以这里自己扫一遍，**保序**。
///
/// ⚠️ 支持的范围**刻意窄**（就锁文件那点形状）：对象 / 字符串 / 整数。
/// 遇到别的（数组、`null`、`\u` 转义、小数）直接抛 —— 旧实现在那种情况下多半也解析得出来，
/// 所以这是**已知的边界**：锁文件一旦长出新形状，这里会先红（**红比静默好**）。
priv suberror JsonMinError {
  JsonMinError(String)
}

///|
/// 一个 JSON 值。
pub enum JVal {
  JNum(Int)
  JStr(String)
  JObj(Array[(String, JVal)])
}

///|
/// 取对象里的键（没有、或不是对象，都给 `None`）。
pub fn JVal::field(self : JVal, key : String) -> JVal? {
  match self {
    JObj(pairs) => {
      let mut found : JVal? = None
      for pair in pairs {
        if pair.0 == key {
          found = Some(pair.1)
        }
      }
      found
    }
    _ => None
  }
}

///|
/// 取字符串。
pub fn JVal::as_str(self : JVal) -> String? {
  match self {
    JStr(s) => Some(s)
    _ => None
  }
}

///|
/// 取整数。
pub fn JVal::as_int(self : JVal) -> Int? {
  match self {
    JNum(n) => Some(n)
    _ => None
  }
}

///|
/// 解析入口（失败抛 `JsonMinError` —— 与旧实现的 `try/catch` 口径一致：调用方当成"读不出来"）。
pub fn parse_json(text : String) -> JVal raise {
  let c = chars(text)
  let (val, next) = parse_value(c, 0)
  let mut i = next
  while i < c.length() && c[i].is_whitespace() {
    i = i + 1
  }
  if i != c.length() {
    raise JsonMinError("尾部还有东西")
  }
  val
}

///|
fn skip_ws(c : Array[Char], i : Int) -> Int {
  let mut k = i
  while k < c.length() && c[k].is_whitespace() {
    k = k + 1
  }
  k
}

///|
fn parse_value(c : Array[Char], i : Int) -> (JVal, Int) raise {
  let k = skip_ws(c, i)
  if k >= c.length() {
    raise JsonMinError("空文档")
  }
  if c[k] == '{' {
    parse_object(c, k)
  } else if c[k] == '"' {
    let (s, next) = parse_string(c, k)
    (JStr(s), next)
  } else if c[k] == '-' || (c[k] >= '0' && c[k] <= '9') {
    parse_number(c, k)
  } else {
    raise JsonMinError("不支持的值")
  }
}

///|
fn parse_object(c : Array[Char], i : Int) -> (JVal, Int) raise {
  let pairs : Array[(String, JVal)] = []
  let mut k = skip_ws(c, i + 1)
  if k < c.length() && c[k] == '}' {
    return (JObj(pairs), k + 1)
  }
  let mut more = true
  while more {
    k = skip_ws(c, k)
    if k >= c.length() || c[k] != '"' {
      raise JsonMinError("键必须是字符串")
    }
    let (key, after_key) = parse_string(c, k)
    k = skip_ws(c, after_key)
    if k >= c.length() || c[k] != ':' {
      raise JsonMinError("缺少冒号")
    }
    let (val, after_val) = parse_value(c, k + 1)
    pairs.push((key, val))
    k = skip_ws(c, after_val)
    if k < c.length() && c[k] == ',' {
      k = k + 1
    } else if k < c.length() && c[k] == '}' {
      more = false
      k = k + 1
    } else {
      raise JsonMinError("对象没闭合")
    }
  }
  (JObj(pairs), k)
}

///|
fn parse_string(c : Array[Char], i : Int) -> (String, Int) raise {
  let mut k = i + 1
  let mut out = ""
  while k < c.length() {
    let ch = c[k]
    if ch == '"' {
      return (out, k + 1)
    }
    if ch == '\\' {
      if k + 1 >= c.length() {
        raise JsonMinError("转义没写完")
      }
      let e = c[k + 1]
      let piece = if e == 'n' {
        "\n"
      } else if e == 't' {
        "\t"
      } else if e == 'r' {
        "\r"
      } else if e == '"' {
        "\""
      } else if e == '\\' {
        "\\"
      } else if e == '/' {
        "/"
      } else {
        raise JsonMinError("不认识的转义")
      }
      out = out + piece
      k = k + 2
      continue
    }
    out = out + ch.to_string()
    k = k + 1
  }
  raise JsonMinError("字符串没闭合")
}

///|
fn parse_number(c : Array[Char], i : Int) -> (JVal, Int) raise {
  let mut k = i
  if k < c.length() && c[k] == '-' {
    k = k + 1
  }
  let start = k
  while k < c.length() && c[k] >= '0' && c[k] <= '9' {
    k = k + 1
  }
  if k == start {
    raise JsonMinError("数字不合法")
  }
  let n = try {
    @string.parse_int(slice(c, i, k))
  } catch {
    _ => raise JsonMinError("数字解析失败")
  }
  (JNum(n), k)
}
