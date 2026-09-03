let allQuestions = [];
let quizQuestions = [];
let currentIndex = 0;
let correctCount = 0;
let answered = false;
let currentChoices = [];
let currentUser = null;
let currentQuizAnswers = [];

const CSV_PATH = "./questions.csv";
const IMAGE_DIR = "./question_images/";

document.addEventListener("DOMContentLoaded", async () => {
  try {
    await loadLoginUser();

    allQuestions = await loadQuestions();
    console.log("Loaded questions:", allQuestions.length);
  } catch (error) {
    console.error(error);
    alert("初期読み込みに失敗しました。ログイン状態またはquestions.csvを確認してください。");
  }
});

async function loadLoginUser() {
  const response = await fetch("/api/me");

  if (!response.ok) {
    window.location.href = "/";
    return;
  }

  const data = await response.json();
  currentUser = data.user;

  const userLabel = `${currentUser.name || currentUser.username} さん`;

  const loginUserText = document.getElementById("loginUserText");
  const resultUserText = document.getElementById("resultUserText");

  if (loginUserText) {
    loginUserText.textContent = `ログイン中：${userLabel}`;
  }

  if (resultUserText) {
    resultUserText.textContent = `ログイン中：${userLabel}`;
  }
}

function getUserKey(baseKey) {
  const username = currentUser && currentUser.username
    ? currentUser.username
    : "guest";

  return `${baseKey}_${username}`;
}

async function loadQuestions() {
  const response = await fetch(CSV_PATH);
  const text = await response.text();
  const rows = parseCSV(text);

  if (rows.length < 2) {
    throw new Error("CSVにデータがありません。");
  }

  const headers = rows[0].map(h => h.trim());

  return rows.slice(1)
    .filter(row => row.some(cell => String(cell).trim() !== ""))
    .map(row => {
      const item = {};
      headers.forEach((header, index) => {
        item[header] = row[index] || "";
      });
      return item;
    });
}

function parseCSV(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    const next = text[i + 1];

    if (char === '"' && inQuotes && next === '"') {
      cell += '"';
      i++;
    } else if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      row.push(cell);
      cell = "";
    } else if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && next === "\n") {
        i++;
      }

      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
    } else {
      cell += char;
    }
  }

  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }

  return rows;
}

function startQuiz(mode, category = null) {
  if (!allQuestions.length) {
    alert("問題データを読み込み中です。少し待ってからもう一度押してください。");
    return;
  }

  let base = [...allQuestions];

  if (mode === "category") {
    base = base.filter(q => normalize(q.Category) === normalize(category));
  }

  if (base.length === 0) {
    alert("対象の問題がありません。CSVのCategoryを確認してください。");
    return;
  }

  const count = mode === "random50" ? 50 : 10;
  quizQuestions = shuffle(base).slice(0, Math.min(count, base.length));

  currentIndex = 0;
  correctCount = 0;
  answered = false;
  currentQuizAnswers = [];

  showScreen("quizScreen");
  showQuestion();
}

function showQuestion() {
  answered = false;

  const q = quizQuestions[currentIndex];

  document.getElementById("progressText").textContent =
    `${currentIndex + 1} / ${quizQuestions.length}`;

  document.getElementById("categoryText").textContent =
    q.Category ? `分野：${q.Category}` : "";

  document.getElementById("yearText").textContent =
    q.Year && q.QuestionNo ? `${q.Year}年 問${q.QuestionNo}` : "";

  document.getElementById("questionTitle").textContent =
    q.IsCountQuestion === "True" || q.IsCountQuestion === "TRUE"
      ? "個数問題"
      : "問題";

  document.getElementById("promptText").textContent = q.Prompt || "";

  setupQuestionImage(q);
  setupChoices(q);

  document.getElementById("judgeBox").className = "judge hidden";
  document.getElementById("judgeBox").textContent = "";

  document.getElementById("explainBtn").classList.add("hidden");
  document.getElementById("explainBtn").textContent = "解説を見る";

  document.getElementById("explanationBox").classList.add("hidden");
  document.getElementById("explanationBox").textContent = "";

  document.getElementById("nextBtn").classList.add("hidden");
}

function setupQuestionImage(q) {
  const wrap = document.getElementById("questionImageWrap");
  const img = document.getElementById("questionImage");

  const imageName = q.QuestionImage || q.PageImage || "";

  if (!imageName.trim()) {
    wrap.classList.add("hidden");
    img.src = "";
    return;
  }

  img.src = IMAGE_DIR + imageName.trim();

  img.onerror = () => {
    wrap.classList.add("hidden");
  };

  wrap.classList.remove("hidden");
}

function setupChoices(q) {
  const choicesDiv = document.getElementById("choices");
  choicesDiv.innerHTML = "";

  const originalChoices = [
    { no: 1, text: q.Choice1 || "" },
    { no: 2, text: q.Choice2 || "" },
    { no: 3, text: q.Choice3 || "" },
    { no: 4, text: q.Choice4 || "" }
  ].filter(c => c.text.trim() !== "");

  const shouldRandomize =
    q.RandomizeChoices === "True" ||
    q.RandomizeChoices === "TRUE" ||
    q.RandomizeChoices === "true";

  currentChoices = shouldRandomize ? shuffle(originalChoices) : originalChoices;

  currentChoices.forEach((choice, index) => {
    const btn = document.createElement("button");
    btn.className = "choice-btn";
    btn.textContent = `${index + 1}. ${choice.text}`;
    btn.onclick = () => answerQuestion(choice.no);
    choicesDiv.appendChild(btn);
  });
}

function answerQuestion(selectedOriginalNo) {
  if (answered) {
    return;
  }

  answered = true;

  const q = quizQuestions[currentIndex];
  const correctOriginalNo = Number(q.OriginalAnswer);

  const buttons = document.querySelectorAll(".choice-btn");

  buttons.forEach((btn, index) => {
    const choice = currentChoices[index];

    if (choice.no === correctOriginalNo) {
      btn.classList.add("correct");
    }

    if (choice.no === selectedOriginalNo && selectedOriginalNo !== correctOriginalNo) {
      btn.classList.add("wrong");
    }

    btn.disabled = true;
  });

  const isCorrect = selectedOriginalNo === correctOriginalNo;
  const judgeBox = document.getElementById("judgeBox");

  if (isCorrect) {
    correctCount++;
    judgeBox.textContent = "正解です！";
    judgeBox.className = "judge correct";
  } else {
    judgeBox.textContent = `不正解です。正解は ${correctOriginalNo} です。`;
    judgeBox.className = "judge wrong";
  }

  document.getElementById("explainBtn").classList.remove("hidden");
  document.getElementById("nextBtn").classList.remove("hidden");

  saveAnswerResult(isCorrect, q);
}

function toggleExplanation() {
  const q = quizQuestions[currentIndex];
  const box = document.getElementById("explanationBox");

  if (box.classList.contains("hidden")) {
    box.textContent = q.Explanation || "解説は登録されていません。";
    box.classList.remove("hidden");
    document.getElementById("explainBtn").textContent = "解説を閉じる";
  } else {
    box.classList.add("hidden");
    document.getElementById("explainBtn").textContent = "解説を見る";
  }
}

function nextQuestion() {
  currentIndex++;

  if (currentIndex >= quizQuestions.length) {
    finishQuiz();
  } else {
    showQuestion();
  }
}

async function finishQuiz() {
  const percent = Math.round((correctCount / quizQuestions.length) * 100);

  const summary = {
    date: new Date().toLocaleString("ja-JP"),
    username: currentUser ? currentUser.username : "",
    name: currentUser ? currentUser.name : "",
    total: quizQuestions.length,
    correct: correctCount,
    percent
  };

  saveLocalQuizSummary(summary);

  try {
    await saveQuizResultToServer(summary, currentQuizAnswers);
  } catch (error) {
    console.error(error);
    alert("サーバー保存に失敗しました。ブラウザ内には保存されています。");
  }

  showResultScreen();
}

async function saveQuizResultToServer(summary, answers) {
  const response = await fetch("/api/results", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      total: summary.total,
      correct: summary.correct,
      percent: summary.percent,
      answers: answers
    })
  });

  const data = await response.json();

  if (!response.ok || !data.ok) {
    throw new Error(data.message || "成績保存に失敗しました。");
  }

  return data;
}

async function showResultScreen() {
  showScreen("resultScreen");

  const resultSummary = document.getElementById("resultSummary");

  if (currentUser) {
    const userLabel = currentUser.name || currentUser.username;
    const resultUserText = document.getElementById("resultUserText");

    if (resultUserText) {
      resultUserText.textContent = `ログイン中：${userLabel} さん`;
    }
  }

  resultSummary.innerHTML = "<p>成績を読み込み中です...</p>";

  try {
    const serverResults = await loadServerResults();
    renderServerResults(serverResults);
  } catch (error) {
    console.error(error);
    renderLocalResults();
  }
}

async function loadServerResults() {
  const response = await fetch("/api/results");
  const data = await response.json();

  if (!response.ok || !data.ok) {
    throw new Error(data.message || "成績取得に失敗しました。");
  }

  return data.results || [];
}

function renderServerResults(results) {
  const resultSummary = document.getElementById("resultSummary");
  const userLabel = currentUser ? currentUser.name || currentUser.username : "";

  let html = "";

  html += `
    <p><strong>対象ユーザー</strong></p>
    <p>${userLabel} さん</p>
    <hr>
  `;

  if (!results.length) {
    html += `<p>まだサーバーに保存された成績はありません。</p>`;
    resultSummary.innerHTML = html;
    return;
  }

  const latest = results[0];

  html += `
    <p><strong>直近の結果</strong></p>
    <p>${latest.correct} / ${latest.total} 問 正解</p>
    <p>正解率：${latest.percent}%</p>
    <p>実施日時：${formatDate(latest.created_at)}</p>
    <hr>
  `;

  const totalAnswered = results.reduce((sum, h) => sum + Number(h.total), 0);
  const totalCorrect = results.reduce((sum, h) => sum + Number(h.correct), 0);
  const totalPercent = totalAnswered
    ? Math.round((totalCorrect / totalAnswered) * 100)
    : 0;

  html += `
    <p><strong>累計成績</strong></p>
    <p>実施回数：${results.length} 回</p>
    <p>回答数：${totalAnswered} 問</p>
    <p>正解数：${totalCorrect} 問</p>
    <p>累計正解率：${totalPercent}%</p>
    <hr>
    <p><strong>履歴</strong></p>
  `;

  html += `<div class="history-list">`;

  results.slice(0, 10).forEach((item, index) => {
    html += `
      <div class="history-item">
        <p><strong>${index + 1}. ${formatDate(item.created_at)}</strong></p>
        <p>${item.correct} / ${item.total} 問 正解　正解率：${item.percent}%</p>
      </div>
    `;
  });

  html += `</div>`;

  resultSummary.innerHTML = html;
}

function renderLocalResults() {
  const resultSummary = document.getElementById("resultSummary");
  const history = getLocalHistory();
  const latest = history[history.length - 1];
  const userLabel = currentUser ? currentUser.name || currentUser.username : "";

  let html = "";

  html += `
    <p><strong>対象ユーザー</strong></p>
    <p>${userLabel} さん</p>
    <hr>
  `;

  html += `
    <p style="color:#a5281d;"><strong>サーバー成績の取得に失敗しました。</strong></p>
    <p>ブラウザ内の成績を表示しています。</p>
    <hr>
  `;

  if (latest) {
    html += `
      <p><strong>直近の結果</strong></p>
      <p>${latest.correct} / ${latest.total} 問 正解</p>
      <p>正解率：${latest.percent}%</p>
      <p>実施日時：${latest.date}</p>
      <hr>
    `;
  } else {
    html += `<p>まだ成績はありません。</p>`;
  }

  if (history.length) {
    const totalAnswered = history.reduce((sum, h) => sum + h.total, 0);
    const totalCorrect = history.reduce((sum, h) => sum + h.correct, 0);
    const totalPercent = Math.round((totalCorrect / totalAnswered) * 100);

    html += `
      <p><strong>累計成績</strong></p>
      <p>実施回数：${history.length} 回</p>
      <p>回答数：${totalAnswered} 問</p>
      <p>正解数：${totalCorrect} 問</p>
      <p>累計正解率：${totalPercent}%</p>
    `;
  }

  resultSummary.innerHTML = html;
}

function saveAnswerResult(isCorrect, q) {
  const answer = {
    date: new Date().toLocaleString("ja-JP"),
    username: currentUser ? currentUser.username : "",
    name: currentUser ? currentUser.name : "",
    id: q.ID || "",
    year: q.Year || "",
    questionNo: q.QuestionNo || "",
    category: q.Category || "",
    correct: isCorrect
  };

  currentQuizAnswers.push(answer);

  const logs = getLocalAnswerLogs();
  logs.push(answer);

  localStorage.setItem(getUserKey("takken_answer_logs"), JSON.stringify(logs.slice(-500)));
}

function saveLocalQuizSummary(summary) {
  const history = getLocalHistory();
  history.push(summary);

  localStorage.setItem(getUserKey("takken_history"), JSON.stringify(history.slice(-50)));
}

function getLocalHistory() {
  return JSON.parse(localStorage.getItem(getUserKey("takken_history")) || "[]");
}

function getLocalAnswerLogs() {
  return JSON.parse(localStorage.getItem(getUserKey("takken_answer_logs")) || "[]");
}

function backToMenu() {
  showScreen("menuScreen");
}

function showScreen(screenId) {
  document.querySelectorAll(".screen").forEach(screen => {
    screen.classList.remove("active");
  });

  document.getElementById(screenId).classList.add("active");
}

function shuffle(array) {
  const copied = [...array];

  for (let i = copied.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copied[i], copied[j]] = [copied[j], copied[i]];
  }

  return copied;
}

function normalize(value) {
  return String(value || "").trim().replace(/\s/g, "");
}

function formatDate(value) {
  if (!value) {
    return "";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString("ja-JP");
}

async function logout() {
  const result = confirm("ログアウトしますか？");

  if (!result) {
    return;
  }

  try {
    await fetch("/api/logout", {
      method: "POST"
    });

    window.location.href = "/";
  } catch (error) {
    alert("ログアウトに失敗しました。");
  }
}
