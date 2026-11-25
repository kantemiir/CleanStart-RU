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
$previous = Read-KnownHashes (Join-Path $data "previous.sha256")

Write-Host "Игра: $GameDir"
Write-Host "Проверяю версию игры..."
# Для каждого файла годится одно из двух состояний:
#  - файл игры оригинальный (как в Steam) — его и сохраняем в бэкап;
#  - файл уже наш (эта или прошлая версия русификатора), а в бэкапе лежит оригинал этой версии игры.
# Бэкап от прошлой версии игры (после обновления в Steam) заменяется свежими оригиналами.
$stale = @(); $needVerify = @(); $refresh = @()
foreach ($rel in $orig.Keys) {
    $cur = Get-Sha (Join-Path $dstRoot $rel)
    $bk = Get-Sha (Join-Path $backup $rel)
    if ($cur -eq $orig[$rel]) {
        if ($bk -ne $orig[$rel]) { $refresh += $rel }
    } elseif ($cur -eq $result[$rel] -or $previous[$rel] -contains $cur) {
        if ($bk -ne $orig[$rel]) { $needVerify += $rel }
    } else {
        $stale += $rel
    }
}
if ($stale.Count) {
    foreach ($rel in $stale) { Write-Host "  не совпадает: $rel" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "Версия игры отличается от той, под которую сделан русификатор (видимо, игра обновилась)." -ForegroundColor Red
    Write-Host "Установка отменена, ничего не изменено. Новая версия русификатора:" -ForegroundColor Red
    Write-Host "  https://github.com/kantemiir/CleanStart-RU/releases/latest"
    Write-Host "Если там пока нет версии под обновление — подождите, она выйдет."
    exit 1
}
if ($needVerify.Count) {
    foreach ($rel in $needVerify) { Write-Host "  в бэкапе нет оригинала: $rel" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "Файлы изменены прошлой версией русификатора, а оригиналов этой версии игры в бэкапе нет." -ForegroundColor Red
    Write-Host "Проверьте файлы в Steam: Clean Start -> Свойства -> Установленные файлы -> Проверить целостность,"
    Write-Host "затем запустите установку снова. Ничего не изменено."
    exit 1
}

# бэкап оригиналов: новый или обновлённый после обновления игры
if ($refresh.Count) {
    foreach ($rel in $refresh) {
        $b = Join-Path $backup $rel
        New-Item -ItemType Directory -Force (Split-Path $b) | Out-Null
        Copy-Item (Join-Path $dstRoot $rel) $b -Force
        if ((Get-Sha $b) -ne $orig[$rel]) { throw "Не удалось сохранить оригинал в бэкап: $rel" }
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
