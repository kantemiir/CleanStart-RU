param([string]$GameDir = "")

# Clean Start — русификатор: удаление (возвращает оригиналы из _backup_ru).

$ErrorActionPreference = "Stop"
$data = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $data "common.ps1")

$GameDir = Resolve-GameDir $GameDir
$dstRoot = Join-Path $GameDir "Clean Start_Data"
$backup = Join-Path $GameDir "_backup_ru"
$result = Read-HashList (Join-Path $data "results.sha256")

if (-not (Test-Path $backup)) {
    Write-Host "Русификатор не установлен (нет папки $backup)." -ForegroundColor Yellow
    Write-Host "Если что-то не так: Steam -> Clean Start -> Свойства -> Установленные файлы -> Проверить целостность."
    exit 0
}
foreach ($b in Get-ChildItem $backup -Recurse -File) {
    $rel = $b.FullName.Substring($backup.Length + 1)
    $dst = Join-Path $dstRoot $rel
    # возвращаем только то, что сейчас наше; если Steam уже обновил файл — не трогаем
    if ((Get-Sha $dst) -eq $result[$rel]) { Copy-Item $b.FullName $dst -Force }
}
Remove-Item $backup -Recurse -Force
Write-Host "Русификатор удалён, оригинальные файлы восстановлены." -ForegroundColor Green
