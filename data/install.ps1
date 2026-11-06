param([string]$GameDir = "")

# Clean Start — русификатор: установка.
# Русский язык встаёт на место польского ("Russian - русский" в настройках),
# в фирменные шрифты игры добавляется кириллица.
# Оригинальные файлы сохраняются в папку _backup_ru в корне игры.

$ErrorActionPreference = "Stop"
$data = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $data "common.ps1")

$GameDir = Resolve-GameDir $GameDir
$dstRoot = Join-Path $GameDir "Clean Start_Data"
$backup = Join-Path $GameDir "_backup_ru"
$orig = Read-HashList (Join-Path $data "originals.sha256")
$result = Read-HashList (Join-Path $data "results.sha256")

Write-Host "Игра: $GameDir"
Write-Host "Проверяю версию игры..."
$stale = $false
foreach ($rel in $orig.Keys) {
    $cur = Get-Sha (Join-Path $dstRoot $rel)
    if ($cur -ne $orig[$rel] -and $cur -ne $result[$rel]) {
        Write-Host "  не совпадает: $rel" -ForegroundColor Yellow
        $stale = $true
    }
}
if (Test-Path $backup) {
    foreach ($rel in $orig.Keys) {
        if ((Get-Sha (Join-Path $backup $rel)) -ne $orig[$rel]) { $stale = $true; Write-Host "  бэкап повреждён: $rel" -ForegroundColor Yellow }
    }
}
if ($stale) {
    Write-Host ""
    Write-Host "Версия игры отличается от той, под которую сделан русификатор (видимо, игра обновилась)." -ForegroundColor Red
    Write-Host "Установка отменена, чтобы ничего не сломать. Нужна новая версия русификатора." -ForegroundColor Red
    Write-Host "Если русификатор уже стоял: Steam -> Clean Start -> Свойства -> Установленные файлы -> Проверить целостность."
    exit 1
}

# бэкап оригиналов (один раз)
if (-not (Test-Path $backup)) {
    foreach ($rel in $orig.Keys) {
        $p = Join-Path $dstRoot $rel
        if ((Get-Sha $p) -ne $orig[$rel]) { throw "Файл уже изменён, а бэкапа нет: $rel. Проверьте целостность файлов в Steam и запустите установку снова." }
        $b = Join-Path $backup $rel
        New-Item -ItemType Directory -Force (Split-Path $b) | Out-Null
        Copy-Item $p $b
    }
    Write-Host "Оригиналы сохранены в $backup"
}

# патчи (шрифты) — применяются к оригиналам из бэкапа
foreach ($patch in Get-ChildItem (Join-Path $data "patches") -Filter *.cspatch) {
    $rel = $patch.BaseName
    $target = Join-Path $dstRoot $rel
    if ((Get-Sha $target) -eq $result[$rel]) { Write-Host "  $rel — уже установлен"; continue }
    Write-Host "  патчу $rel ..."
    $tmp = "$target.ru_tmp"
    Apply-CsPatch (Join-Path $backup $rel) $patch.FullName $tmp
    if ((Get-Sha $tmp) -ne $result[$rel]) { Remove-Item $tmp -Force; throw "Патч $rel дал неверный результат." }
    Move-Item $tmp $target -Force
}

# готовые файлы (тексты, каталог)
$files = Join-Path $data "files"
foreach ($f in Get-ChildItem $files -Recurse -File) {
    $rel = $f.FullName.Substring($files.Length + 1)
    $dst = Join-Path $dstRoot $rel
    Copy-Item $f.FullName $dst -Force
    if ((Get-Sha $dst) -ne $result[$rel]) { throw "Не удалось записать $rel" }
}

Write-Host ""
Write-Host "Готово! Запустите игру: Options -> Game -> Language -> 'Russian - русский'." -ForegroundColor Green
Write-Host "Язык переключается в главном меню (до начала или продолжения игры)."
