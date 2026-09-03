const express = require("express");
const path = require("path");

const app = express();

app.use(express.json());

// publicフォルダの中身を表示
app.use(express.static(path.join(__dirname, "public")));

// 動作確認用
app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    message: "takken-app is running"
  });
});

// Renderでは process.env.PORT が必要
const PORT = process.env.PORT || 3000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
