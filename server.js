const express = require("express");
const path = require("path");
const session = require("express-session");

const app = express();

const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, "public");

const ADMIN_USER = process.env.ADMIN_USER || "admin";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;
const SESSION_SECRET = process.env.SESSION_SECRET || "change-this-secret";

app.set("trust proxy", 1);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(
  session({
    name: "takken.sid",
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: "lax",
      secure: false,
      maxAge: 1000 * 60 * 60 * 8
    }
  })
);

// 動作確認用
app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    message: "takken-app is running"
  });
});

// ログイン画面
app.get("/", (req, res) => {
  if (req.session.user) {
    return res.redirect("/index.html");
  }

  res.sendFile(path.join(PUBLIC_DIR, "login.html"));
});

app.get("/login.html", (req, res) => {
  if (req.session.user) {
    return res.redirect("/index.html");
  }

  res.sendFile(path.join(PUBLIC_DIR, "login.html"));
});

// ログイン処理
app.post("/api/login", (req, res) => {
  const { username, password } = req.body;

  if (!ADMIN_PASSWORD) {
    return res.status(500).json({
      ok: false,
      message: "Render側にADMIN_PASSWORDが設定されていません。"
    });
  }

  if (username === ADMIN_USER && password === ADMIN_PASSWORD) {
    req.session.user = {
      username: ADMIN_USER,
      loginAt: new Date().toISOString()
    };

    return res.json({
      ok: true,
      message: "ログイン成功"
    });
  }

  return res.status(401).json({
    ok: false,
    message: "IDまたはパスワードが違います。"
  });
});

// ログイン状態確認
app.get("/api/me", (req, res) => {
  if (!req.session.user) {
    return res.status(401).json({
      ok: false,
      message: "未ログインです。"
    });
  }

  res.json({
    ok: true,
    user: req.session.user
  });
});

// ログアウト
app.post("/api/logout", (req, res) => {
  req.session.destroy(() => {
    res.clearCookie("takken.sid");
    res.json({
      ok: true,
      message: "ログアウトしました。"
    });
  });
});

app.get("/logout", (req, res) => {
  req.session.destroy(() => {
    res.clearCookie("takken.sid");
    res.redirect("/");
  });
});

// ここから下はログイン必須
function requireLogin(req, res, next) {
  if (req.session.user) {
    return next();
  }

  if (req.method === "GET") {
    return res.redirect("/");
  }

  return res.status(401).json({
    ok: false,
    message: "ログインが必要です。"
  });
}

app.use(requireLogin, express.static(PUBLIC_DIR));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
