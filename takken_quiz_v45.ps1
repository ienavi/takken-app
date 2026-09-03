Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$questionsPath = Join-Path $scriptDir "questions.csv"
$resultsPath = Join-Path $scriptDir "results.csv"
$imageDir = Join-Path $scriptDir "question_images"
$menuBgPath = Join-Path $scriptDir "menu_house_bg.jpg"
$menuExactPath = Join-Path $scriptDir "menu_exact.png"
$quizExactPath = Join-Path $scriptDir "quiz_exact.png"
$quizBgCleanPath = Join-Path $scriptDir "quiz_bg_clean.png"
$quizBgRefinedPath = Join-Path $scriptDir "quiz_bg_refined.png"
$quizBgRefined2Path = Join-Path $scriptDir "quiz_bg_refined2.png"
$quizBgDesignedPath = Join-Path $scriptDir "quiz_bg_designed.png"
$quizBgCustomPath = Join-Path $scriptDir "quiz_bg_custom.png"

if (!(Test-Path $questionsPath)) {
    [System.Windows.Forms.MessageBox]::Show("questions.csv が見つかりません。", "エラー")
    exit
}

function ToBool($v) {
    if ($v -eq "TRUE" -or $v -eq "true" -or $v -eq "1") { return $true }
    return $false
}

function New-QuestionObject($row) {
    $ansText = [string]$row.OriginalAnswer
    $answers = @()
    if ($ansText -eq "ALL" -or $ansText -eq "全て" -or $ansText -eq "0") {
        $answers = @(1,2,3,4)
    } else {
        $parts = $ansText -split "[,、 ]+"
        foreach ($p in $parts) {
            $n = 0
            if ([int]::TryParse($p, [ref]$n)) {
                if ($n -ge 1 -and $n -le 4) { $answers += $n }
            }
        }
    }
    if ($answers.Count -eq 0) { $answers = @(1) }
    return @{
        ID = [string]$row.ID
        Year = [string]$row.Year
        QuestionNo = [string]$row.QuestionNo
        Category = [string]$row.Category
        IsCountQuestion = ToBool $row.IsCountQuestion
        OriginalAnswers = $answers
        Explanation = [string]$row.Explanation
        Source = [string]$row.Source
        QuestionImage = [string]$row.QuestionImage
    }
}

function Load-Questions {
    try {
        $rows = Import-Csv -Path $questionsPath -Encoding UTF8
        $list = @()
        foreach ($row in $rows) {
            if ($row.QuestionImage -and $row.OriginalAnswer) {
                $imgPath = Join-Path $imageDir ([string]$row.QuestionImage)
                if (Test-Path $imgPath) { $list += New-QuestionObject $row }
            }
        }
        return $list
    } catch {
        [System.Windows.Forms.MessageBox]::Show("questions.csv の読み込みに失敗しました。", "CSVエラー")
        exit
    }
}

function Ensure-ResultsFile {
    if (!(Test-Path $resultsPath)) {
        "DateTime,Mode,SessionId,Year,QuestionNo,Category,QuestionType,QuestionID,SelectedAnswer,CorrectAnswer,IsCorrect" | Out-File -FilePath $resultsPath -Encoding UTF8
    }
}

function Add-ResultRow($record) {
    Ensure-ResultsFile
    $line = '"' + ($record.DateTime -replace '"','""') + '","' +
            ($record.Mode -replace '"','""') + '","' +
            ($record.SessionId -replace '"','""') + '","' +
            ($record.Year -replace '"','""') + '","' +
            ($record.QuestionNo -replace '"','""') + '","' +
            ($record.Category -replace '"','""') + '","' +
            ($record.QuestionType -replace '"','""') + '","' +
            ($record.QuestionID -replace '"','""') + '","' +
            ($record.SelectedAnswer -replace '"','""') + '","' +
            ($record.CorrectAnswer -replace '"','""') + '","' +
            ($record.IsCorrect -replace '"','""') + '"'
    Add-Content -Path $resultsPath -Value $line -Encoding UTF8
}

function Get-WeakAnalysisText($records) {
    $wrong = @($records | Where-Object { $_.IsCorrect -eq "FALSE" })
    if ($wrong.Count -eq 0) { return "今回の間違いはありません。`r`n" }
    $text = "間違えやすい分野`r`n"
    $groups = $wrong | Group-Object Category | Sort-Object Count -Descending
    foreach ($g in $groups) { $text += "・" + $g.Name + "：" + $g.Count + "問`r`n" }
    $text += "`r`n間違えた問題`r`n"
    foreach ($r in $wrong) {
        $text += "・" + $r.Year + "年 問" + $r.QuestionNo + " / " + $r.Category + " / 正解：" + $r.CorrectAnswer + " / 回答：" + $r.SelectedAnswer + "`r`n"
    }
    return $text
}

$questions = Load-Questions
if ($questions.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("有効な問題画像がありません。", "エラー")
    exit
}

$card = [System.Drawing.Color]::White
$navy = [System.Drawing.Color]::FromArgb(30, 50, 75)
$blue = [System.Drawing.Color]::FromArgb(45, 105, 210)
$lightBlue = [System.Drawing.Color]::FromArgb(235, 242, 255)
$grayText = [System.Drawing.Color]::FromArgb(90, 95, 105)
$border = [System.Drawing.Color]::FromArgb(205, 215, 230)

$form = New-Object System.Windows.Forms.Form
$form.Text = "宅建問題"
$form.Size = New-Object System.Drawing.Size(1160, 900)
$form.MinimumSize = New-Object System.Drawing.Size(1040, 820)
$form.StartPosition = "CenterScreen"
$form.TopMost = $false
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.ControlBox = $true
$form.BackColor = $card
$form.Font = New-Object System.Drawing.Font("Meiryo", 9)

$menuPanel = New-Object System.Windows.Forms.Panel
$menuPanel.Dock = "Fill"
$form.Controls.Add($menuPanel)

$quizPanel = New-Object System.Windows.Forms.Panel
$quizPanel.Dock = "Fill"
$quizPanel.BackColor = [System.Drawing.Color]::FromArgb(233, 222, 204)

$quizBg = New-Object System.Windows.Forms.PictureBox
$quizBg.Dock = 'Fill'
$quizBg.SizeMode = 'StretchImage'
$quizBg.Visible = $false
if (Test-Path $quizBgCustomPath) {
    $quizBg.Image = [System.Drawing.Image]::FromFile($quizBgCustomPath)
    $quizBg.Visible = $true
} elseif (Test-Path $quizBgDesignedPath) {
    $quizBg.Image = [System.Drawing.Image]::FromFile($quizBgDesignedPath)
    $quizBg.Visible = $true
} elseif (Test-Path $quizBgRefined2Path) {
    $quizBg.Image = [System.Drawing.Image]::FromFile($quizBgRefined2Path)
    $quizBg.Visible = $true
} elseif (Test-Path $quizBgRefinedPath) {
    $quizBg.Image = [System.Drawing.Image]::FromFile($quizBgRefinedPath)
    $quizBg.Visible = $true
} elseif (Test-Path $quizBgCleanPath) {
    $quizBg.Image = [System.Drawing.Image]::FromFile($quizBgCleanPath)
    $quizBg.Visible = $true
} elseif (Test-Path $quizExactPath) {
    $quizBg.Image = [System.Drawing.Image]::FromFile($quizExactPath)
    $quizBg.Visible = $true
}
$quizPanel.Controls.Add($quizBg)
$quizPanel.Visible = $false
$form.Controls.Add($quizPanel)

$scorePanel = New-Object System.Windows.Forms.Panel
$scorePanel.Dock = "Fill"
$scorePanel.BackColor = [System.Drawing.Color]::FromArgb(232, 237, 244)
$scorePanel.Visible = $false
$form.Controls.Add($scorePanel)

$menuBg = New-Object System.Windows.Forms.PictureBox
$menuBg.Dock = 'Fill'
$menuBg.SizeMode = 'Zoom'
$menuBg.Visible = $true
if (Test-Path $menuExactPath) {
    $menuBg.Image = [System.Drawing.Image]::FromFile($menuExactPath)
} elseif (Test-Path $menuBgPath) {
    $menuBg.Image = [System.Drawing.Image]::FromFile($menuBgPath)
}
$menuPanel.BackColor = [System.Drawing.Color]::FromArgb(232, 225, 214)
$menuPanel.Controls.Add($menuBg)
$menuBg.BringToFront()

$menuOverlay = New-Object System.Windows.Forms.Panel
$menuOverlay.BackColor = [System.Drawing.Color]::FromArgb(184, 149, 109)
$menuOverlay.Size = New-Object System.Drawing.Size(500, 760)
$menuOverlay.BorderStyle = 'FixedSingle'
$menuPanel.Controls.Add($menuOverlay)
$menuOverlay.Visible = $false

$menuInner = New-Object System.Windows.Forms.Panel
$menuInner.BackColor = [System.Drawing.Color]::FromArgb(249, 246, 238)
$menuInner.Size = New-Object System.Drawing.Size(416, 670)
$menuInner.Location = New-Object System.Drawing.Point(42, 34)
$menuInner.BorderStyle = 'FixedSingle'
$menuOverlay.Controls.Add($menuInner)

function Center-MenuOverlay {
    # 画像メニューのクリック領域を、表示中の画像位置に合わせる
    $baseW = 813.0
    $baseH = 1024.0
    $panelW = [double]$menuBg.ClientSize.Width
    $panelH = [double]$menuBg.ClientSize.Height

    $scale = [Math]::Min($panelW / $baseW, $panelH / $baseH)
    $shownW = [double]($baseW * $scale)
    $shownH = [double]($baseH * $scale)
    $offsetX = [double](($panelW - $shownW) / 2.0)
    $offsetY = [double](($panelH - $shownH) / 2.0)

    function Set-Area($ctrl, $x, $y, $w, $h) {
        $ctrl.Left = [int]($offsetX + ($x * $scale))
        $ctrl.Top = [int]($offsetY + ($y * $scale))
        $ctrl.Width = [int]($w * $scale)
        $ctrl.Height = [int]($h * $scale)
    }

    # 旧メニュー部品は非表示のまま
    $menuOverlay.Left = -5000
    $menuOverlay.Top = -5000
    $menuOverlay.Visible = $false

    # 参考画像に合わせたクリック範囲
    Set-Area $click50       202 246 383 62
    Set-Area $click10       203 332 382 60
    Set-Area $clickRights   203 460 383 63
    Set-Area $clickTakkenLaw 203 543 383 63
    Set-Area $clickLegalLimit 203 626 383 63
    Set-Area $clickTaxOther 203 710 383 63
    Set-Area $clickScores   203 791 383 68
}

function New-MenuButton($text, $y) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Font = New-Object System.Drawing.Font('Meiryo', 11.5, [System.Drawing.FontStyle]::Bold)
    $b.Size = New-Object System.Drawing.Size(320, 48)
    $b.Location = New-Object System.Drawing.Point(48, $y)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.FlatAppearance.MouseOverBackColor = $b.BackColor
    $b.FlatAppearance.MouseDownBackColor = $b.BackColor
    return $b
}

function Set-PrimaryMenuButtonStyle($b) {
    $b.BackColor = [System.Drawing.Color]::FromArgb(88, 89, 138)
    $b.ForeColor = [System.Drawing.Color]::White
}

function Set-WoodMenuButtonStyle($b) {
    $b.BackColor = [System.Drawing.Color]::FromArgb(218, 195, 164)
    $b.ForeColor = [System.Drawing.Color]::FromArgb(28, 33, 52)
}

function Set-ScoreMenuButtonStyle($b) {
    $b.BackColor = [System.Drawing.Color]::FromArgb(224, 204, 168)
    $b.ForeColor = [System.Drawing.Color]::FromArgb(28, 33, 52)
}


$menuTitle = New-Object System.Windows.Forms.Label
$menuTitle.Text = '宅建問題'
$menuTitle.Font = New-Object System.Drawing.Font('Yu Mincho', 24, [System.Drawing.FontStyle]::Bold)
$menuTitle.ForeColor = [System.Drawing.Color]::FromArgb(31, 33, 73)
$menuTitle.AutoSize = $true
$menuTitle.Location = New-Object System.Drawing.Point(54, 34)
$menuInner.Controls.Add($menuTitle)

$menuDesc = New-Object System.Windows.Forms.Label
$menuDesc.Text = '学習モードを選択'
$menuDesc.Font = New-Object System.Drawing.Font('Yu Mincho', 10.5)
$menuDesc.ForeColor = [System.Drawing.Color]::FromArgb(55, 51, 47)
$menuDesc.AutoSize = $true
$menuDesc.Location = New-Object System.Drawing.Point(58, 92)
$menuInner.Controls.Add($menuDesc)

$btn50 = New-MenuButton '常時ランダム50問' 150
$menuInner.Controls.Add($btn50)

$btn10 = New-MenuButton 'ランダム10問' 208
$menuInner.Controls.Add($btn10)

$categoryLabel = New-Object System.Windows.Forms.Label
$categoryLabel.Text = '分野別10問'
$categoryLabel.Font = New-Object System.Drawing.Font('Yu Mincho', 10.5, [System.Drawing.FontStyle]::Bold)
$categoryLabel.ForeColor = [System.Drawing.Color]::FromArgb(31, 33, 73)
$categoryLabel.AutoSize = $true
$categoryLabel.Location = New-Object System.Drawing.Point(58, 278)
$menuInner.Controls.Add($categoryLabel)

$btnRights = New-MenuButton '権利関係 10問' 308
$menuInner.Controls.Add($btnRights)

$btnTakkenLaw = New-MenuButton '宅建業法 10問' 366
$menuInner.Controls.Add($btnTakkenLaw)

$btnLegalLimit = New-MenuButton '法令上の制限 10問' 424
$menuInner.Controls.Add($btnLegalLimit)

$btnTaxOther = New-MenuButton '税・その他 10問' 482
$menuInner.Controls.Add($btnTaxOther)

$btnExempt = New-MenuButton '免除科目 10問' 540
$menuInner.Controls.Add($btnExempt)

$btnScores = New-MenuButton '成績' 598
$menuInner.Controls.Add($btnScores)

$menuInfo = New-Object System.Windows.Forms.Label
$menuInfo.Text = ''
$menuInfo.Font = New-Object System.Drawing.Font('Yu Mincho', 8.5)
$menuInfo.ForeColor = [System.Drawing.Color]::FromArgb(70, 65, 58)
$menuInfo.AutoSize = $true
$menuInfo.Location = New-Object System.Drawing.Point(290, 645)
$menuInner.Controls.Add($menuInfo)

Set-PrimaryMenuButtonStyle $btn50
Set-PrimaryMenuButtonStyle $btn10
Set-WoodMenuButtonStyle $btnRights
Set-WoodMenuButtonStyle $btnTakkenLaw
Set-WoodMenuButtonStyle $btnLegalLimit
Set-WoodMenuButtonStyle $btnTaxOther
Set-WoodMenuButtonStyle $btnExempt
Set-ScoreMenuButtonStyle $btnScores


# 表示は画像をそのまま使い、クリックだけを受ける領域を画像の上に直接重ねる
# ※ 前回は menuPanel 上の透明Panelが画像を隠していたため、今回は PictureBox(menuBg) の子要素にする
function New-MenuClickArea($name) {
    $l = New-Object System.Windows.Forms.Label
    $l.Name = $name
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.Cursor = [System.Windows.Forms.Cursors]::Hand
    $l.Text = ''
    $menuBg.Controls.Add($l)
    return $l
}

$click50 = New-MenuClickArea 'click50'
$click10 = New-MenuClickArea 'click10'
$clickRights = New-MenuClickArea 'clickRights'
$clickTakkenLaw = New-MenuClickArea 'clickTakkenLaw'
$clickLegalLimit = New-MenuClickArea 'clickLegalLimit'
$clickTaxOther = New-MenuClickArea 'clickTaxOther'
$clickScores = New-MenuClickArea 'clickScores'
# quiz layout
$topBar = New-Object System.Windows.Forms.Panel
$topBar.BackColor = [System.Drawing.Color]::FromArgb(248, 245, 238)
$quizPanel.Controls.Add($topBar)

$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.Font = New-Object System.Drawing.Font('Meiryo', 10, [System.Drawing.FontStyle]::Bold)
$headerLabel.ForeColor = $navy
$topBar.Controls.Add($headerLabel)

$progressLabel = New-Object System.Windows.Forms.Label
$progressLabel.Font = New-Object System.Drawing.Font('Meiryo', 8)
$progressLabel.ForeColor = $grayText
$topBar.Controls.Add($progressLabel)

$progressCircle = New-Object System.Windows.Forms.Panel
$progressCircle.BackColor = [System.Drawing.Color]::White
$progressCircle.BorderStyle = 'FixedSingle'
$quizPanel.Controls.Add($progressCircle)

$progressNumber = New-Object System.Windows.Forms.Label
$progressNumber.Font = New-Object System.Drawing.Font('Meiryo', 20, [System.Drawing.FontStyle]::Bold)
$progressNumber.TextAlign = 'MiddleCenter'
$progressCircle.Controls.Add($progressNumber)


$backToMenuButton = New-Object System.Windows.Forms.Button
$backToMenuButton.Text = 'メニュー'
$backToMenuButton.Font = New-Object System.Drawing.Font('Meiryo', 8, [System.Drawing.FontStyle]::Bold)
$backToMenuButton.BackColor = $lightBlue
$backToMenuButton.ForeColor = $navy
$backToMenuButton.FlatStyle = 'Flat'
$backToMenuButton.FlatAppearance.BorderColor = $border
$topBar.Controls.Add($backToMenuButton)

$imagePanel = New-Object System.Windows.Forms.Panel
$imagePanel.BackColor = $card
$imagePanel.AutoScroll = $true
$imagePanel.BorderStyle = 'FixedSingle'
$quizPanel.Controls.Add($imagePanel)

$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.SizeMode = 'StretchImage'
$imagePanel.Controls.Add($pictureBox)

$answerPanel = New-Object System.Windows.Forms.Panel
$answerPanel.BackColor = [System.Drawing.Color]::FromArgb(233, 222, 204)
$quizPanel.Controls.Add($answerPanel)

$answerButtons = @()
for ($i = 0; $i -lt 4; $i++) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = [string]($i + 1)
    $b.Font = New-Object System.Drawing.Font('Meiryo', 14, [System.Drawing.FontStyle]::Bold)
    $b.Size = New-Object System.Drawing.Size(68, 45)
    $b.Tag = $i + 1
    $b.BackColor = [System.Drawing.Color]::FromArgb(108, 78, 51)
    $b.ForeColor = [System.Drawing.Color]::FromArgb(248, 237, 197)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = $border
    $answerButtons += $b
    $answerPanel.Controls.Add($b)
}

$nextButton = New-Object System.Windows.Forms.Button
$nextButton.Text = '次へ'
$nextButton.Font = New-Object System.Drawing.Font('Meiryo', 10, [System.Drawing.FontStyle]::Bold)
$nextButton.Enabled = $false
$nextButton.BackColor = $blue
$nextButton.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$nextButton.FlatStyle = 'Flat'
$nextButton.FlatAppearance.BorderSize = 0
$answerPanel.Controls.Add($nextButton)

$explanationBox = New-Object System.Windows.Forms.RichTextBox
$explanationBox.ReadOnly = $true
$explanationBox.Font = New-Object System.Drawing.Font('Meiryo', 8)
$explanationBox.ScrollBars = 'Vertical'
$explanationBox.BackColor = $card
$explanationBox.BorderStyle = 'FixedSingle'
$quizPanel.Controls.Add($explanationBox)
$explanationBox.Visible = $false

$resultLabel = New-Object System.Windows.Forms.Label
$resultLabel.Font = New-Object System.Drawing.Font('Meiryo', 10, [System.Drawing.FontStyle]::Bold)
$resultLabel.ForeColor = $grayText
$resultLabel.TextAlign = 'MiddleCenter'
        $resultLabel.Text = '回答すると解説リンクが使えます。'
$quizPanel.Controls.Add($resultLabel)

$linkPanel = New-Object System.Windows.Forms.Panel
$linkPanel.BackColor = [System.Drawing.Color]::FromArgb(233, 222, 204)
$quizPanel.Controls.Add($linkPanel)

$youtubeButton = New-Object System.Windows.Forms.Button
$youtubeButton.Text = 'YouTube解説'
$youtubeButton.Font = New-Object System.Drawing.Font('Meiryo', 9, [System.Drawing.FontStyle]::Bold)
$youtubeButton.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$youtubeButton.ForeColor = [System.Drawing.Color]::FromArgb(40, 50, 75)
$youtubeButton.FlatStyle = 'Flat'
$youtubeButton.FlatAppearance.BorderColor = $border
$youtubeButton.Enabled = $false
$linkPanel.Controls.Add($youtubeButton)

$siteButton = New-Object System.Windows.Forms.Button
$siteButton.Text = 'サイト解説'
$siteButton.Font = New-Object System.Drawing.Font('Meiryo', 9, [System.Drawing.FontStyle]::Bold)
$siteButton.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$siteButton.ForeColor = [System.Drawing.Color]::FromArgb(40, 50, 75)
$siteButton.FlatStyle = 'Flat'
$siteButton.FlatAppearance.BorderColor = $border
$siteButton.Enabled = $false
$linkPanel.Controls.Add($siteButton)

# background button click areas (transparent hotspots on the background image)
$answerHotspots = @()
for ($i = 0; $i -lt 4; $i++) {
    $hs = New-Object System.Windows.Forms.Label
    $hs.Tag = $i + 1
    $hs.Text = ''
    $hs.BackColor = [System.Drawing.Color]::Transparent
    $hs.AutoSize = $false
    $hs.BorderStyle = 'None'
    $hs.Cursor = [System.Windows.Forms.Cursors]::Hand
    $hs.Enabled = $true
    $answerHotspots += $hs
    $quizBg.Controls.Add($hs)
}
$nextHotspot = New-Object System.Windows.Forms.Label
$nextHotspot.Text = ''
$nextHotspot.BackColor = [System.Drawing.Color]::Transparent
$nextHotspot.AutoSize = $false
$nextHotspot.BorderStyle = 'None'
$nextHotspot.Cursor = [System.Windows.Forms.Cursors]::Hand
$quizBg.Controls.Add($nextHotspot)

$topBar.BringToFront()
$progressCircle.BringToFront()
$imagePanel.BringToFront()
$answerPanel.BringToFront()
$resultLabel.BringToFront()
$linkPanel.BringToFront()

# score panel
$scoreTitle = New-Object System.Windows.Forms.Label
$scoreTitle.Text = '成績'
$scoreTitle.Font = New-Object System.Drawing.Font('Meiryo', 20, [System.Drawing.FontStyle]::Bold)
$scoreTitle.ForeColor = $navy
$scoreTitle.AutoSize = $true
$scoreTitle.Location = New-Object System.Drawing.Point(25, 25)
$scorePanel.Controls.Add($scoreTitle)

$scoreBox = New-Object System.Windows.Forms.RichTextBox
$scoreBox.ReadOnly = $true
$scoreBox.Font = New-Object System.Drawing.Font('Meiryo', 9)
$scoreBox.ScrollBars = 'Vertical'
$scoreBox.BackColor = $card
$scoreBox.BorderStyle = 'FixedSingle'
$scoreBox.Visible = $false
$scorePanel.Controls.Add($scoreBox)

$backMenuButton = New-Object System.Windows.Forms.Button
$backMenuButton.Text = 'メニューへ戻る'
$backMenuButton.Font = New-Object System.Drawing.Font('Meiryo', 10, [System.Drawing.FontStyle]::Bold)
$backMenuButton.BackColor = $lightBlue
$backMenuButton.ForeColor = $navy
$backMenuButton.FlatStyle = 'Flat'
$backMenuButton.FlatAppearance.BorderColor = $border
$scorePanel.Controls.Add($backMenuButton)

# ----- Score dashboard controls -----
$scoreHeader = New-Object System.Windows.Forms.Label
$scoreHeader.Text = '成績報告書'
$scoreHeader.Font = New-Object System.Drawing.Font('Meiryo', 24, [System.Drawing.FontStyle]::Bold)
$scoreHeader.ForeColor = [System.Drawing.Color]::FromArgb(24, 42, 69)
$scoreHeader.AutoSize = $true
$scorePanel.Controls.Add($scoreHeader)

$cardTotal = New-Object System.Windows.Forms.Panel
$cardTotal.BackColor = [System.Drawing.Color]::White
$cardTotal.BorderStyle = 'FixedSingle'
$scorePanel.Controls.Add($cardTotal)

$cardRank = New-Object System.Windows.Forms.Panel
$cardRank.BackColor = [System.Drawing.Color]::White
$cardRank.BorderStyle = 'FixedSingle'
$scorePanel.Controls.Add($cardRank)

$cardRecent = New-Object System.Windows.Forms.Panel
$cardRecent.BackColor = [System.Drawing.Color]::White
$cardRecent.BorderStyle = 'FixedSingle'
$scorePanel.Controls.Add($cardRecent)

$cardTotalTitle = New-Object System.Windows.Forms.Label
$cardTotalTitle.Text = '累計成績'
$cardTotalTitle.Font = New-Object System.Drawing.Font('Meiryo', 18, [System.Drawing.FontStyle]::Bold)
$cardTotalTitle.ForeColor = [System.Drawing.Color]::Black
$cardTotalTitle.AutoSize = $true
$cardTotal.Controls.Add($cardTotalTitle)

$cardRankTitle = New-Object System.Windows.Forms.Label
$cardRankTitle.Text = '間違いやすい分野ランキング'
$cardRankTitle.Font = New-Object System.Drawing.Font('Meiryo', 17, [System.Drawing.FontStyle]::Bold)
$cardRankTitle.ForeColor = [System.Drawing.Color]::Black
$cardRankTitle.AutoSize = $true
$cardRank.Controls.Add($cardRankTitle)

$cardRecentTitle = New-Object System.Windows.Forms.Label
$cardRecentTitle.Text = '直近の間違いの詳細'
$cardRecentTitle.Font = New-Object System.Drawing.Font('Meiryo', 17, [System.Drawing.FontStyle]::Bold)
$cardRecentTitle.ForeColor = [System.Drawing.Color]::Black
$cardRecentTitle.AutoSize = $true
$cardRecent.Controls.Add($cardRecentTitle)

$totalLabelTitle = New-Object System.Windows.Forms.Label
$totalLabelTitle.Text = '総回答数'
$totalLabelTitle.Font = New-Object System.Drawing.Font('Meiryo', 14, [System.Drawing.FontStyle]::Bold)
$totalLabelTitle.AutoSize = $true
$cardTotal.Controls.Add($totalLabelTitle)

$rateLabelTitle = New-Object System.Windows.Forms.Label
$rateLabelTitle.Text = '正解率'
$rateLabelTitle.Font = New-Object System.Drawing.Font('Meiryo', 14, [System.Drawing.FontStyle]::Bold)
$rateLabelTitle.AutoSize = $true
$cardTotal.Controls.Add($rateLabelTitle)

$totalCircle = New-Object System.Windows.Forms.Panel
$totalCircle.BackColor = [System.Drawing.Color]::White
$totalCircle.BorderStyle = 'FixedSingle'
$cardTotal.Controls.Add($totalCircle)

$rateCircle = New-Object System.Windows.Forms.Panel
$rateCircle.BackColor = [System.Drawing.Color]::White
$rateCircle.BorderStyle = 'FixedSingle'
$cardTotal.Controls.Add($rateCircle)

$totalValue = New-Object System.Windows.Forms.Label
$totalValue.Font = New-Object System.Drawing.Font('Meiryo', 28, [System.Drawing.FontStyle]::Bold)
$totalValue.ForeColor = [System.Drawing.Color]::FromArgb(57, 142, 228)
$totalValue.TextAlign = 'MiddleCenter'
$totalCircle.Controls.Add($totalValue)

$totalSub = New-Object System.Windows.Forms.Label
$totalSub.Font = New-Object System.Drawing.Font('Meiryo', 12)
$totalSub.ForeColor = [System.Drawing.Color]::FromArgb(90,90,90)
$totalSub.TextAlign = 'MiddleCenter'
$totalCircle.Controls.Add($totalSub)

$rateValue = New-Object System.Windows.Forms.Label
$rateValue.Font = New-Object System.Drawing.Font('Meiryo', 28, [System.Drawing.FontStyle]::Bold)
$rateValue.ForeColor = [System.Drawing.Color]::FromArgb(228, 67, 86)
$rateValue.TextAlign = 'MiddleCenter'
$rateCircle.Controls.Add($rateValue)

$correctCard = New-Object System.Windows.Forms.Panel
$correctCard.BackColor = [System.Drawing.Color]::FromArgb(248, 248, 248)
$correctCard.BorderStyle = 'FixedSingle'
$cardTotal.Controls.Add($correctCard)

$wrongCard = New-Object System.Windows.Forms.Panel
$wrongCard.BackColor = [System.Drawing.Color]::FromArgb(248, 248, 248)
$wrongCard.BorderStyle = 'FixedSingle'
$cardTotal.Controls.Add($wrongCard)

$correctIcon = New-Object System.Windows.Forms.Label
$correctIcon.Text = '✓'
$correctIcon.Font = New-Object System.Drawing.Font('Meiryo', 26, [System.Drawing.FontStyle]::Bold)
$correctIcon.ForeColor = [System.Drawing.Color]::FromArgb(75, 188, 136)
$correctIcon.AutoSize = $true
$correctCard.Controls.Add($correctIcon)

$correctStat = New-Object System.Windows.Forms.Label
$correctStat.Font = New-Object System.Drawing.Font('Meiryo', 16, [System.Drawing.FontStyle]::Bold)
$correctStat.ForeColor = [System.Drawing.Color]::FromArgb(75, 188, 136)
$correctStat.AutoSize = $true
$correctCard.Controls.Add($correctStat)

$correctCaption = New-Object System.Windows.Forms.Label
$correctCaption.Text = '正答'
$correctCaption.Font = New-Object System.Drawing.Font('Meiryo', 12, [System.Drawing.FontStyle]::Bold)
$correctCaption.AutoSize = $true
$correctCard.Controls.Add($correctCaption)

$wrongIcon = New-Object System.Windows.Forms.Label
$wrongIcon.Text = '×'
$wrongIcon.Font = New-Object System.Drawing.Font('Meiryo', 26, [System.Drawing.FontStyle]::Bold)
$wrongIcon.ForeColor = [System.Drawing.Color]::FromArgb(233, 84, 84)
$wrongIcon.AutoSize = $true
$wrongCard.Controls.Add($wrongIcon)

$wrongStat = New-Object System.Windows.Forms.Label
$wrongStat.Font = New-Object System.Drawing.Font('Meiryo', 16, [System.Drawing.FontStyle]::Bold)
$wrongStat.ForeColor = [System.Drawing.Color]::FromArgb(233, 84, 84)
$wrongStat.AutoSize = $true
$wrongCard.Controls.Add($wrongStat)

$wrongCaption = New-Object System.Windows.Forms.Label
$wrongCaption.Text = '誤答'
$wrongCaption.Font = New-Object System.Drawing.Font('Meiryo', 12, [System.Drawing.FontStyle]::Bold)
$wrongCaption.AutoSize = $true
$wrongCard.Controls.Add($wrongCaption)

$rankLabels = @()
$rankBars = @()
$rankValues = @()
$rankCats = @('権利関係','宅建業法','法令上の制限','税・その他','免除科目')
foreach ($cat in $rankCats) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $cat
    $lbl.Font = New-Object System.Drawing.Font('Meiryo', 13, [System.Drawing.FontStyle]::Bold)
    $lbl.AutoSize = $true
    $cardRank.Controls.Add($lbl)
    $rankLabels += $lbl

    $track = New-Object System.Windows.Forms.Panel
    $track.BackColor = [System.Drawing.Color]::FromArgb(229, 233, 239)
    $cardRank.Controls.Add($track)

    $fill = New-Object System.Windows.Forms.Panel
    $fill.BackColor = [System.Drawing.Color]::FromArgb(77, 164, 255)
    $track.Controls.Add($fill)
    $rankBars += $fill

    $val = New-Object System.Windows.Forms.Label
    $val.Font = New-Object System.Drawing.Font('Meiryo', 13, [System.Drawing.FontStyle]::Bold)
    $val.AutoSize = $true
    $cardRank.Controls.Add($val)
    $rankValues += $val
}

$rankFirstLabel = New-Object System.Windows.Forms.Label
$rankFirstLabel.Text = '1位'
$rankFirstLabel.Font = New-Object System.Drawing.Font('Meiryo', 20, [System.Drawing.FontStyle]::Bold)
$rankFirstLabel.AutoSize = $true
$cardRank.Controls.Add($rankFirstLabel)

$recentList = New-Object System.Windows.Forms.ListView
$recentList.View = 'Details'
$recentList.FullRowSelect = $true
$recentList.GridLines = $true
$recentList.HideSelection = $false
$recentList.Font = New-Object System.Drawing.Font('Meiryo', 11)
$null = $recentList.Columns.Add('日時', 180)
$null = $recentList.Columns.Add('問題情報', 190)
$null = $recentList.Columns.Add('分野', 160)
$null = $recentList.Columns.Add('回答', 90)
$null = $recentList.Columns.Add('正解', 90)
$cardRecent.Controls.Add($recentList)
$cardRecent.Visible = $false
$recentList.Visible = $false
$cardRecentTitle.Visible = $false


$script:currentLoadedImage = $null
$sessionQuestions = @(); $sessionRecords = @(); $currentIndex = 0; $currentQuestion = $null; $currentMode = ''; $sessionId = ''

function Layout-Quiz {
    if ($quizPanel.Visible -eq $true) {
        $clientW = [int]$quizPanel.ClientSize.Width
        $clientH = [int]$quizPanel.ClientSize.Height
        $quizBg.SendToBack()
        $sx = $clientW / 1432.0
        $sy = $clientH / 967.0

        # header and progress keep the current nice look
        $topBar.Location = New-Object System.Drawing.Point([int](329 * $sx), [int](57 * $sy))
        $topBar.Size = New-Object System.Drawing.Size([int](695 * $sx), [int](59 * $sy))
        $topBar.BackColor = [System.Drawing.Color]::FromArgb(245, 240, 231)
        $topBar.BorderStyle = 'FixedSingle'
        $headerLabel.Location = New-Object System.Drawing.Point([int](18 * $sx), [int](12 * $sy))
        $headerLabel.Size = New-Object System.Drawing.Size([int](505 * $sx), [int](30 * $sy))
        $headerLabel.Font = New-Object System.Drawing.Font('Meiryo', 14, [System.Drawing.FontStyle]::Bold)
        $headerLabel.ForeColor = [System.Drawing.Color]::FromArgb(74, 58, 40)
        $backToMenuButton.Size = New-Object System.Drawing.Size([int](180 * $sx), [int](39 * $sy))
        $backToMenuButton.Location = New-Object System.Drawing.Point([int](520 * $sx), [int](9 * $sy))
        $backToMenuButton.BackColor = [System.Drawing.Color]::White
        $backToMenuButton.ForeColor = [System.Drawing.Color]::FromArgb(74, 58, 40)
        $backToMenuButton.FlatStyle = 'Flat'
        $backToMenuButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(210, 198, 178)
        $backToMenuButton.FlatAppearance.BorderSize = 1

        $progressCircle.Location = New-Object System.Drawing.Point([int](1064 * $sx), [int](58 * $sy))
        $progressCircle.Size = New-Object System.Drawing.Size([int](130 * $sx), [int](83 * $sy))
        $progressCircle.BackColor = [System.Drawing.Color]::FromArgb(250,248,243)
        $progressCircle.BorderStyle = 'FixedSingle'
        $progressNumber.Location = New-Object System.Drawing.Point(0, [int](18 * $sy))
        $progressNumber.Size = New-Object System.Drawing.Size($progressCircle.Width, [int](38 * $sy))
        $progressNumber.Font = New-Object System.Drawing.Font('Meiryo', 18, [System.Drawing.FontStyle]::Bold)
        $progressNumber.ForeColor = [System.Drawing.Color]::FromArgb(64, 50, 35)
        $progressLabel.Location = New-Object System.Drawing.Point([int](1072 * $sx), [int](146 * $sy))
        $progressLabel.Size = New-Object System.Drawing.Size([int](110 * $sx), [int](22 * $sy))
        $progressLabel.Font = New-Object System.Drawing.Font('Meiryo', 10.5, [System.Drawing.FontStyle]::Bold)
        $progressLabel.ForeColor = [System.Drawing.Color]::FromArgb(64, 50, 35)
        $progressLabel.TextAlign = 'MiddleCenter'

        # question block
        $imagePanel.Location = New-Object System.Drawing.Point([int](346 * $sx), [int](138 * $sy))
        $imagePanel.Size = New-Object System.Drawing.Size([int](760 * $sx), [int](390 * $sy))
        if ($imagePanel.Width -lt 700) { $imagePanel.Size = New-Object System.Drawing.Size(700, [Math]::Max(340,[int](390 * $sy))) }
        $imagePanel.BackColor = [System.Drawing.Color]::FromArgb(248,246,243)
        $imagePanel.BorderStyle = 'None'
        $imagePanel.AutoScroll = $true

        # status and link buttons clearly above the answer buttons
        $resultLabel.Location = New-Object System.Drawing.Point(0, [int](592 * $sy))
        $resultLabel.Size = New-Object System.Drawing.Size($clientW, [int](28 * $sy))
        $resultLabel.Font = New-Object System.Drawing.Font('Meiryo', 12, [System.Drawing.FontStyle]::Bold)
        $resultLabel.ForeColor = [System.Drawing.Color]::FromArgb(198, 54, 36)
        $resultLabel.BackColor = [System.Drawing.Color]::FromArgb(248, 244, 235)
        $resultLabel.TextAlign = 'MiddleCenter'
        if ([string]::IsNullOrWhiteSpace($resultLabel.Text)) { $resultLabel.Text = '回答すると解説リンクが使えます。' }

        $linkPanel.Location = New-Object System.Drawing.Point([int](385 * $sx), [int](627 * $sy))
        $linkPanel.Size = New-Object System.Drawing.Size([int](585 * $sx), [int](44 * $sy))
        $linkPanel.BackColor = [System.Drawing.Color]::Transparent
        $youtubeButton.Size = New-Object System.Drawing.Size([int](220 * $sx), [int](34 * $sy))
        $siteButton.Size = New-Object System.Drawing.Size([int](220 * $sx), [int](34 * $sy))
        $youtubeButton.Location = New-Object System.Drawing.Point(0, [int](5 * $sy))
        $siteButton.Location = New-Object System.Drawing.Point([int](290 * $sx), [int](5 * $sy))
        $youtubeButton.Font = New-Object System.Drawing.Font('Meiryo', 10, [System.Drawing.FontStyle]::Bold)
        $siteButton.Font = New-Object System.Drawing.Font('Meiryo', 10, [System.Drawing.FontStyle]::Bold)
        $youtubeButton.BackColor = [System.Drawing.Color]::FromArgb(249,249,247)
        $siteButton.BackColor = [System.Drawing.Color]::FromArgb(249,249,247)

        # the old button panel remains hidden
        $answerPanel.Visible = $false
        foreach ($b in $answerButtons) { $b.Visible = $false }
        $nextButton.Visible = $false

        # clickable hotspots in QUIZ PANEL coordinates, aligned to the visible background buttons
        $btnY = [int](781 * $sy)
        $btnW = [int](94 * $sx); if ($btnW -lt 78) { $btnW = 78 }
        $btnH = [int](73 * $sy); if ($btnH -lt 60) { $btnH = 60 }
        $xs = @([int](382 * $sx), [int](520 * $sx), [int](659 * $sx), [int](798 * $sx))
        for ($i = 0; $i -lt 4; $i++) {
            $answerHotspots[$i].Visible = $true
            $answerHotspots[$i].Location = New-Object System.Drawing.Point($xs[$i], $btnY)
            $answerHotspots[$i].Size = New-Object System.Drawing.Size($btnW, $btnH)
            $answerHotspots[$i].BringToFront()
        }
        $nextHotspot.Visible = $true
        $nextHotspot.Location = New-Object System.Drawing.Point([int](942 * $sx), [int](780 * $sy))
        $nextHotspot.Size = New-Object System.Drawing.Size([int](155 * $sx), [int](76 * $sy))
        if ($nextHotspot.Width -lt 120) { $nextHotspot.Size = New-Object System.Drawing.Size(120, $nextHotspot.Height) }
        if ($nextHotspot.Height -lt 62) { $nextHotspot.Size = New-Object System.Drawing.Size($nextHotspot.Width, 62) }
        $nextHotspot.BringToFront()

        $explanationBox.Visible = $false
        $topBar.BringToFront(); $progressCircle.BringToFront(); $imagePanel.BringToFront(); $resultLabel.BringToFront(); $linkPanel.BringToFront();
        if ($script:currentQuestion -ne $null) { Set-QuestionImage $script:currentQuestion.QuestionImage }
    }
}

function Layout-Score {
    $scoreClientW = [int]$scorePanel.ClientSize.Width
    $scoreClientH = [int]$scorePanel.ClientSize.Height
    if ($scoreClientW -lt 980) { $scoreClientW = 980 }
    if ($scoreClientH -lt 760) { $scoreClientH = 760 }

    $scoreTitle.Visible = $false
    $scoreBox.Visible = $false
    $cardRecent.Visible = $false
    $recentList.Visible = $false
    $cardRecentTitle.Visible = $false

    $scoreHeader.Location = New-Object System.Drawing.Point(18, 14)
    $scoreHeader.Font = New-Object System.Drawing.Font('Meiryo', 21, [System.Drawing.FontStyle]::Bold)
    $backMenuButton.Size = New-Object System.Drawing.Size(128, 40)
    $backMenuButton.Location = New-Object System.Drawing.Point([int]($scoreClientW - 146), 16)
    $backMenuButton.BackColor = [System.Drawing.Color]::White
    $backMenuButton.FlatStyle = 'Flat'

    $cardW = 470; $cardH = 400
    $leftX = [int](($scoreClientW - ($cardW * 2) - 36) / 2); if ($leftX -lt 30) { $leftX = 30 }
    $rightX = [int]($leftX + $cardW + 36); $topY = 90
    $cardTotal.Location = New-Object System.Drawing.Point($leftX, $topY); $cardTotal.Size = New-Object System.Drawing.Size($cardW, $cardH)
    $cardRank.Location = New-Object System.Drawing.Point($rightX, $topY); $cardRank.Size = New-Object System.Drawing.Size($cardW, $cardH)

    $cardTotalTitle.Location = New-Object System.Drawing.Point(20, 14); $cardTotalTitle.Font = New-Object System.Drawing.Font('Meiryo', 16, [System.Drawing.FontStyle]::Bold)
    $cardRankTitle.Location = New-Object System.Drawing.Point(20, 14); $cardRankTitle.Font = New-Object System.Drawing.Font('Meiryo', 15, [System.Drawing.FontStyle]::Bold)
    $totalLabelTitle.Location = New-Object System.Drawing.Point(70, 60); $totalLabelTitle.Font = New-Object System.Drawing.Font('Meiryo', 12, [System.Drawing.FontStyle]::Bold)
    $rateLabelTitle.Location = New-Object System.Drawing.Point(275, 60); $rateLabelTitle.Font = New-Object System.Drawing.Font('Meiryo', 12, [System.Drawing.FontStyle]::Bold)
    $totalCircle.Location = New-Object System.Drawing.Point(45, 98); $totalCircle.Size = New-Object System.Drawing.Size(155, 135)
    $rateCircle.Location = New-Object System.Drawing.Point(248, 98); $rateCircle.Size = New-Object System.Drawing.Size(155, 135)
    $totalValue.Location = New-Object System.Drawing.Point(0, 24); $totalValue.Size = New-Object System.Drawing.Size(155, 48)
    $totalSub.Location = New-Object System.Drawing.Point(0, 78); $totalSub.Size = New-Object System.Drawing.Size(155, 24)
    $rateValue.Location = New-Object System.Drawing.Point(0, 38); $rateValue.Size = New-Object System.Drawing.Size(155, 48)

    $correctCard.Location = New-Object System.Drawing.Point(45, 270); $correctCard.Size = New-Object System.Drawing.Size(170, 92)
    $wrongCard.Location = New-Object System.Drawing.Point(233, 270); $wrongCard.Size = New-Object System.Drawing.Size(180, 92)
    $correctIcon.Location = New-Object System.Drawing.Point(14, 16); $correctIcon.Font = New-Object System.Drawing.Font('Meiryo', 22, [System.Drawing.FontStyle]::Bold)
    $correctCaption.Location = New-Object System.Drawing.Point(56, 14); $correctCaption.Size = New-Object System.Drawing.Size(80, 24); $correctCaption.Font = New-Object System.Drawing.Font('Meiryo', 11, [System.Drawing.FontStyle]::Bold)
    $correctStat.Location = New-Object System.Drawing.Point(56, 46); $correctStat.Size = New-Object System.Drawing.Size(80, 28); $correctStat.Font = New-Object System.Drawing.Font('Meiryo', 16, [System.Drawing.FontStyle]::Bold)

    $wrongIcon.Location = New-Object System.Drawing.Point(14, 16); $wrongIcon.Font = New-Object System.Drawing.Font('Meiryo', 22, [System.Drawing.FontStyle]::Bold)
    $wrongCaption.Location = New-Object System.Drawing.Point(50, 14); $wrongCaption.Size = New-Object System.Drawing.Size(90, 24); $wrongCaption.Font = New-Object System.Drawing.Font('Meiryo', 11, [System.Drawing.FontStyle]::Bold)
    $wrongStat.Location = New-Object System.Drawing.Point(50, 46); $wrongStat.Size = New-Object System.Drawing.Size(90, 28); $wrongStat.Font = New-Object System.Drawing.Font('Meiryo', 16, [System.Drawing.FontStyle]::Bold)

    $rankFirstLabel.Location = New-Object System.Drawing.Point(388, 14); $rankFirstLabel.Font = New-Object System.Drawing.Font('Meiryo', 16, [System.Drawing.FontStyle]::Bold)
    for ($i = 0; $i -lt $rankLabels.Count; $i++) {
        $y = [int](78 + ($i * 58))
        $rankLabels[$i].Location = New-Object System.Drawing.Point(30, $y)
        $rankLabels[$i].Font = New-Object System.Drawing.Font('Meiryo', 10.5, [System.Drawing.FontStyle]::Bold)
        $track = $rankBars[$i].Parent
        $track.Location = New-Object System.Drawing.Point(175, [int]($y + 6))
        $track.Size = New-Object System.Drawing.Size(205, 18)
        $rankBars[$i].Location = New-Object System.Drawing.Point(0, 0)
        $rankValues[$i].Location = New-Object System.Drawing.Point(396, [int]($y - 2))
        $rankValues[$i].Font = New-Object System.Drawing.Font('Meiryo', 11, [System.Drawing.FontStyle]::Bold)
    }
}

$form.Add_Resize({
    Center-MenuOverlay
    Layout-Quiz
    Layout-Score
})

function Show-Menu {
    $scorePanel.Visible = $false
    $quizPanel.Visible = $false
    $menuPanel.Visible = $true
    Center-MenuOverlay
}
function Show-Quiz {
    $menuPanel.Visible = $false
    $scorePanel.Visible = $false
    $quizPanel.Visible = $true
    Layout-Quiz
}


function Set-QuestionImage($imgFile) {
    $path = Join-Path $imageDir $imgFile
    if ($script:currentLoadedImage -ne $null) {
        $pictureBox.Image = $null
        $script:currentLoadedImage.Dispose()
        $script:currentLoadedImage = $null
    }
    $fs = New-Object System.IO.FileStream($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
    $img = [System.Drawing.Image]::FromStream($fs)
    $bmp = New-Object System.Drawing.Bitmap($img)
    $img.Dispose(); $fs.Close()
    $script:currentLoadedImage = $bmp
    $pictureBox.Image = $bmp
    $targetWidth = [int]($imagePanel.ClientSize.Width - 28)
    if ($targetWidth -lt 540) { $targetWidth = 540 }
    $ratio = $bmp.Height / $bmp.Width
    $targetHeight = [int]($targetWidth * $ratio)
    $pictureBox.Location = New-Object System.Drawing.Point(12, 12)
    $pictureBox.Size = New-Object System.Drawing.Size($targetWidth, $targetHeight)
    $imagePanel.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)
}

function Get-QuestionSearchText {
    if ($script:currentQuestion -eq $null) { return '宅建 過去問 解説' }

    $yearText = [string]$script:currentQuestion.Year
    $qnoText = [string]$script:currentQuestion.QuestionNo
    $categoryText = [string]$script:currentQuestion.Category

    return "宅建 過去問 " + $yearText + "年 問" + $qnoText + " " + $categoryText + " 解説"
}

function Open-Url($url) {
    try {
        Start-Process $url
    } catch {
        [System.Windows.Forms.MessageBox]::Show("ブラウザを開けませんでした。`r`n" + $url, "リンクエラー")
    }
}

function Open-YouTubeExplanation {
    $query = Get-QuestionSearchText
    $encoded = [System.Net.WebUtility]::UrlEncode($query)
    $url = "https://www.youtube.com/results?search_query=" + $encoded
    Open-Url $url
}

function Open-SiteExplanation {
    $query = Get-QuestionSearchText
    $encoded = [System.Net.WebUtility]::UrlEncode($query)
    $url = "https://www.google.com/search?q=" + $encoded
    Open-Url $url
}

function Start-Session($count, $modeName) {
    $script:currentMode = $modeName
    $script:sessionId = (Get-Date).ToString('yyyyMMddHHmmss')
    $script:sessionRecords = @()
    $script:currentIndex = 0
    $max = [Math]::Min($count, $questions.Count)
    $script:sessionQuestions = @($questions | Get-Random -Count $max)
    Show-Quiz
    Load-CurrentQuestion
}

function Start-CategorySession($categoryName) {
    $script:currentMode = $categoryName + ' 10問'
    $script:sessionId = (Get-Date).ToString('yyyyMMddHHmmss')
    $script:sessionRecords = @()
    $script:currentIndex = 0

    $filtered = @($questions | Where-Object { $_.Category -eq $categoryName })

    if ($filtered.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show($categoryName + ' の問題が見つかりません。', '問題なし')
        return
    }

    $max = [Math]::Min(10, $filtered.Count)
    $script:sessionQuestions = @($filtered | Get-Random -Count $max)

    Show-Quiz
    Load-CurrentQuestion
}

function Load-CurrentQuestion {
    $script:currentQuestion = $script:sessionQuestions[$script:currentIndex]
    $qType = '通常問題'
    if ($script:currentQuestion.IsCountQuestion) { $qType = '個数問題' }
    $headerLabel.Text = $script:currentMode + '　' + $script:currentQuestion.Year + '年　問' + $script:currentQuestion.QuestionNo + '　' + $qType
    $progressLabel.Text = '進捗：' + ($script:currentIndex + 1) + ' / ' + $script:sessionQuestions.Count
    $progressNumber.Text = ($script:currentIndex + 1).ToString() + ' / ' + $script:sessionQuestions.Count.ToString()
    Set-QuestionImage $script:currentQuestion.QuestionImage
    $resultLabel.ForeColor = $grayText
    $resultLabel.Text = '回答すると解説リンクが使えます。'
    $youtubeButton.Enabled = $false
    $siteButton.Enabled = $false
    foreach ($b in $answerButtons) { $b.Enabled = $true; $b.BackColor = [System.Drawing.Color]::FromArgb(108, 78, 51); $b.ForeColor = [System.Drawing.Color]::FromArgb(248, 237, 197) }
    $nextButton.Enabled = $false
    if ($script:currentIndex -eq ($script:sessionQuestions.Count - 1)) { $nextButton.Text = '結果' } else { $nextButton.Text = '次へ' }
}
function Answer-Question($selected) {
    foreach ($b in $answerButtons) { $b.Enabled = $false }
    $correctNumbers = @($script:currentQuestion.OriginalAnswers)
    $isCorrect = $correctNumbers -contains [int]$selected
    $correctText = ($correctNumbers | ForEach-Object { [string]$_ }) -join '、'
    if ($isCorrect) {
        $resultLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 135, 65)
        $resultLabel.Text = '正解です　/　あなたの回答：' + $selected + '　/　正解：' + $correctText
    } else {
        $resultLabel.ForeColor = [System.Drawing.Color]::FromArgb(190, 45, 45)
        $resultLabel.Text = '不正解です　/　あなたの回答：' + $selected + '　/　正解：' + $correctText
    }
    $record = [PSCustomObject]@{
        DateTime = (Get-Date).ToString('yyyy/MM/dd HH:mm:ss')
        Mode = $script:currentMode
        SessionId = $script:sessionId
        Year = $script:currentQuestion.Year
        QuestionNo = $script:currentQuestion.QuestionNo
        Category = $script:currentQuestion.Category
        QuestionType = $(if ($script:currentQuestion.IsCountQuestion) { '個数問題' } else { '通常問題' })
        QuestionID = $script:currentQuestion.ID
        SelectedAnswer = [string]$selected
        CorrectAnswer = $correctText
        IsCorrect = $(if ($isCorrect) { 'TRUE' } else { 'FALSE' })
    }
    $script:sessionRecords += $record
    Add-ResultRow $record

    # 回答後に解説リンクを開けるようにする
    $youtubeButton.Enabled = $true
    $siteButton.Enabled = $true

    $nextButton.Enabled = $true
}
function Update-ScoreDashboard($titleText, $records) {
    if ($records -eq $null) { $records = @() }
    $total = @($records).Count
    $correct = @($records | Where-Object { $_.IsCorrect -eq 'TRUE' }).Count
    $wrong = $total - $correct
    $rate = 0
    if ($total -gt 0) { $rate = [Math]::Round(($correct / $total) * 100, 1) }

    if ($titleText -is [array]) {
        $scoreHeader.Text = [string]$titleText[0]
    } else {
        $scoreHeader.Text = [string]$titleText
    }
    $totalValue.Text = $total.ToString()
    $totalSub.Text = '/ ' + $total.ToString()
    $rateValue.Text = $rate.ToString() + '%'
    $correctStat.Text = $correct.ToString() + '問'
    $wrongStat.Text = $wrong.ToString() + '問'

    $wrongGroups = @($records | Where-Object { $_.IsCorrect -eq 'FALSE' } | Group-Object Category | Sort-Object Count -Descending)
    $maxWrong = 1
    if ($wrongGroups.Count -gt 0) { $maxWrong = [Math]::Max(1, $wrongGroups[0].Count) }
    for ($i = 0; $i -lt $rankLabels.Count; $i++) {
        $cat = $rankCats[$i]
        $grp = $wrongGroups | Where-Object { $_.Name -eq $cat } | Select-Object -First 1
        $count = 0
        if ($grp -ne $null) { $count = [int]$grp.Count }
        $track = $rankBars[$i].Parent
        $trackWidth = [int]$rankBars[$i].Parent.Width
        if ($trackWidth -lt 1) { $trackWidth = 150 }
        $fillW = [int]($trackWidth * ($count / $maxWrong))
        if ($count -le 0) { $fillW = 0 }
        $rankBars[$i].Size = New-Object System.Drawing.Size($fillW, 18)
        if ($i -eq 0) { $rankBars[$i].BackColor = [System.Drawing.Color]::FromArgb(77, 164, 255) }
        elseif ($i -eq 1) { $rankBars[$i].BackColor = [System.Drawing.Color]::FromArgb(114, 190, 255) }
        else { $rankBars[$i].BackColor = [System.Drawing.Color]::FromArgb(200, 209, 224) }
        $rankValues[$i].Text = $count.ToString()
    }

    $recentList.Items.Clear()
    $recentWrongs = @($records | Where-Object { $_.IsCorrect -eq 'FALSE' } | Sort-Object DateTime -Descending | Select-Object -First 20)
    foreach ($r in $recentWrongs) {
        $item = New-Object System.Windows.Forms.ListViewItem('[' + $r.DateTime + ']')
        [void]$item.SubItems.Add('[' + $r.Year + '年 問' + $r.QuestionNo + ']')
        [void]$item.SubItems.Add($r.Category)
        [void]$item.SubItems.Add('[' + $r.SelectedAnswer + ']')
        [void]$item.SubItems.Add($r.CorrectAnswer)
        [void]$recentList.Items.Add($item)
    }
    if ($recentWrongs.Count -eq 0) {
        $item = New-Object System.Windows.Forms.ListViewItem('まだ間違いはありません')
        [void]$item.SubItems.Add('')
        [void]$item.SubItems.Add('')
        [void]$item.SubItems.Add('')
        [void]$item.SubItems.Add('')
        [void]$recentList.Items.Add($item)
    }

    $menuPanel.Visible = $false
    $quizPanel.Visible = $false
    $scorePanel.Visible = $true
    Layout-Score
}

function Finish-Session {
    Update-ScoreDashboard "今回の成績" $script:sessionRecords
}

function Show-AllScores {
    Ensure-ResultsFile
    try {
        $records = @(Import-Csv -Path $resultsPath -Encoding UTF8)
    } catch {
        $records = @()
    }
    Update-ScoreDashboard "成績報告書" $records
}

$btn50.Add_Click({ Start-Session 50 '常時ランダム50問' })
$btn10.Add_Click({ Start-Session 10 'ランダム10問' })

$btnRights.Add_Click({ Start-CategorySession '権利関係' })
$btnTakkenLaw.Add_Click({ Start-CategorySession '宅建業法' })
$btnLegalLimit.Add_Click({ Start-CategorySession '法令上の制限' })
$btnTaxOther.Add_Click({ Start-CategorySession '税・その他' })
$btnExempt.Add_Click({ Start-CategorySession '免除科目' })

$btnScores.Add_Click({ Show-AllScores })

# 画像メニューのクリック
$click50.Add_Click({ Start-Session 50 '常時ランダム50問' })
$click10.Add_Click({ Start-Session 10 'ランダム10問' })
$clickRights.Add_Click({ Start-CategorySession '権利関係' })
$clickTakkenLaw.Add_Click({ Start-CategorySession '宅建業法' })
$clickLegalLimit.Add_Click({ Start-CategorySession '法令上の制限' })
$clickTaxOther.Add_Click({ Start-CategorySession '税・その他' })
$clickScores.Add_Click({ Show-AllScores })
$backMenuButton.Add_Click({ Show-Menu })
$backToMenuButton.Add_Click({ Show-Menu })

$youtubeButton.Add_Click({ Open-YouTubeExplanation })
$siteButton.Add_Click({ Open-SiteExplanation })
foreach ($b in $answerButtons) { $b.Add_Click({ $selected = [int]$this.Tag; Answer-Question $selected }) }
foreach ($hs in $answerHotspots) { $hs.Add_Click({ $selected = [int]$this.Tag; Answer-Question $selected }) }
$nextAction = { if ($script:currentIndex -ge ($script:sessionQuestions.Count - 1)) { Finish-Session } else { $script:currentIndex++; Load-CurrentQuestion } }
$nextButton.Add_Click($nextAction)
$nextHotspot.Add_Click($nextAction)

Center-MenuOverlay
Layout-Score
Show-Menu
[void]$form.ShowDialog()
