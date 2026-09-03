let allQuestions = [];
let quizQuestions = [];
let currentIndex = 0;
let correctCount = 0;
let answered = false;
let currentChoices = [];

const CSV_PATH = "./questions.csv";
const IMAGE_DIR = "./question_images/";

document.addEventListener("DOMContentLoaded", async () => {
  try {
    allQuestions = await loadQuestions();
    console.log("Loaded questions:", allQuestions.length);
  } catch (error) {
    alert("問題データの読み込みに失敗しました。questions.csvを確認してください。");
    console.error(error);
  }
});

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
      if (char === "\r" && next === "\n") i++;
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
    btn.onclick = () => answerQuestion(choice.no, btn);
    choicesDiv.appendChild(btn);
  });
}

function answerQuestion(selectedOriginalNo, clickedButton) {
  if (answered) return;

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

function finishQuiz() {
  const percent = Math.round((correctCount / quizQuestions.length) * 100);

  const history = getHistory();
  history.push({
    date: new Date().toLocaleString("ja-JP"),
    total: quizQuestions.length,
    correct: correctCount,
    percent
  });

  localStorage.setItem("takken_history", JSON.stringify(history.slice(-50)));

  showResultScreen();
}

function showResultScreen() {
  showScreen("resultScreen");

  const history = getHistory();
  const latest = history[history.length - 1];

  let html = "";

  if (latest) {
    html += `
      <p><strong>直近の結果</strong></p>
      <p>${latest.correct} / ${latest.total} 問 正解</p>
      <p>正解率：${latest.percent}%</p>
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
      <p>回答数：${totalAnswered} 問</p>
      <p>正解数：${totalCorrect} 問</p>
      <p>累計正解率：${totalPercent}%</p>
    `;
  }

  document.getElementById("resultSummary").innerHTML = html;
}

function saveAnswerResult(isCorrect, q) {
  const logs = JSON.parse(localStorage.getItem("takken_answer_logs") || "[]");

  logs.push({
    date: new Date().toLocaleString("ja-JP"),
    id: q.ID || "",
    year: q.Year || "",
    questionNo: q.QuestionNo || "",
    category: q.Category || "",
    correct: isCorrect
  });

  localStorage.setItem("takken_answer_logs", JSON.stringify(logs.slice(-500)));
}

function getHistory() {
  return JSON.parse(localStorage.getItem("takken_history") || "[]");
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
