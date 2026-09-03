const express = require("express");
const path = require("path");
const session = require("express-session");

const app = express();

const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, "public");

const SESSION_SECRET = process.env.SESSION_SECRET || "change-this-secret";

// 複数ユーザー設定
// Renderの環境変数 APP_USERS にJSON形式で登録します
function getUsers() {
  try {
    if (process.env.APP_USERS) {
      return JSON.parse(process.env.APP_USERS);
    }
  } catch (error) {
    console.error("APP_USERSの形式が正しくありません。", error);
  }

  // 予備：APP_USERSが未設定の場合は従来のadminログインを使う
  return [
    {
      username: process.env.ADMIN_USER || "admin",
      password: process.env.ADMIN_PASSWORD || "",
      role: "admin",
      name: "管理者"
    }
  ];
}

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

app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    message: "takken-app is running"
  });
});

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

app.post("/api/login", (req, res) => {
  const { username, password } = req.body;

  const users = getUsers();

  const user = users.find(
    u => u.username === username && u.password === password
  );

  if (!user) {
    return res.status(401).json({
      ok: false,
      message: "IDまたはパスワードが違います。"
    });
  }

  req.session.user = {
    username: user.username,
    role: user.role || "user",
    name: user.name || user.username,
    loginAt: new Date().toISOString()
  };

  return res.json({
    ok: true,
    message: "ログイン成功",
    user: req.session.user
  });
});

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
