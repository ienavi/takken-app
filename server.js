const express = require("express");
const path = require("path");
const session = require("express-session");
const { Pool } = require("pg");

const app = express();

const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, "public");

const SESSION_SECRET = process.env.SESSION_SECRET || "change-this-secret";

const pool = process.env.DATABASE_URL
  ? new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: {
        rejectUnauthorized: false
      }
    })
  : null;

function getUsers() {
  try {
    if (process.env.APP_USERS) {
      return JSON.parse(process.env.APP_USERS);
    }
  } catch (error) {
    console.error("APP_USERSの形式が正しくありません。", error);
  }

  return [
    {
      username: process.env.ADMIN_USER || "admin",
      password: process.env.ADMIN_PASSWORD || "",
      role: "admin",
      name: "管理者"
    }
  ];
}

async function initDatabase() {
  if (!pool) {
    console.warn("DATABASE_URLが未設定です。成績のサーバー保存は無効です。");
    return;
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS quiz_results (
      id SERIAL PRIMARY KEY,
      username TEXT NOT NULL,
      name TEXT,
      total INTEGER NOT NULL,
      correct INTEGER NOT NULL,
      percent INTEGER NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS answer_logs (
      id SERIAL PRIMARY KEY,
      username TEXT NOT NULL,
      name TEXT,
      question_id TEXT,
      year TEXT,
      question_no TEXT,
      category TEXT,
      correct BOOLEAN NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  console.log("Database initialized");
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
    message: "takken-app is running",
    database: pool ? "connected setting exists" : "DATABASE_URL not set"
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

app.post("/api/results", requireLogin, async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      ok: false,
      message: "DATABASE_URLが設定されていません。"
    });
  }

  const user = req.session.user;
  const { total, correct, percent, answers } = req.body;

  try {
    await pool.query(
      `
      INSERT INTO quiz_results (username, name, total, correct, percent)
      VALUES ($1, $2, $3, $4, $5)
      `,
      [
        user.username,
        user.name,
        Number(total),
        Number(correct),
        Number(percent)
      ]
    );

    if (Array.isArray(answers)) {
      for (const answer of answers) {
        await pool.query(
          `
          INSERT INTO answer_logs
          (username, name, question_id, year, question_no, category, correct)
          VALUES ($1, $2, $3, $4, $5, $6, $7)
          `,
          [
            user.username,
            user.name,
            answer.id || "",
            answer.year || "",
            answer.questionNo || "",
            answer.category || "",
            Boolean(answer.correct)
          ]
        );
      }
    }

    res.json({
      ok: true,
      message: "成績を保存しました。"
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      ok: false,
      message: "成績保存に失敗しました。"
    });
  }
});

app.get("/api/results", requireLogin, async (req, res) => {
  if (!pool) {
    return res.status(500).json({
      ok: false,
      message: "DATABASE_URLが設定されていません。"
    });
  }

  const user = req.session.user;

  try {
    const result = await pool.query(
      `
      SELECT id, username, name, total, correct, percent, created_at
      FROM quiz_results
      WHERE username = $1
      ORDER BY created_at DESC
      LIMIT 50
      `,
      [user.username]
    );

    res.json({
      ok: true,
      results: result.rows
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      ok: false,
      message: "成績取得に失敗しました。"
    });
  }
});

app.use(requireLogin, express.static(PUBLIC_DIR));

initDatabase()
  .then(() => {
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch(error => {
    console.error("Database initialization failed", error);

    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Server running on port ${PORT}`);
    });
  });
