$file = "c:\Users\bruno\Documents\Projects\html\prisma\profile.html"
$content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)

$replacements = @{
    "ðŸŽ¯" = [char]0x1F3AF  # 🎯
    "ðŸ'»" = [char]0x1F47B  # 👻
    "âš¡" = [char]0x26A1    # ⚡
    "ðŸ†" = [char]0x1F3C6  # 🏆
    "PerfeiÃ§Ã£o" = "Perfeição"
    "ðŸ'£" = [char]0x1F4A3  # 💣
    "ðŸ"«" = [char]0x1F52B  # 🔫
    "ðŸ''" = [char]0x1F451  # 👑
}

foreach ($key in $replacements.Keys) {
    $content = $content.Replace($key, $replacements[$key])
}

[System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
Write-Host "Encoding corrigido!"
