# Общие функции установщика русификатора Clean Start.

function Find-Game {
    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    $libs = @()
    if ($steam) {
        $libs += $steam
        $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            $libs += Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\', '\' }
        }
    }
    $libs += "C:\Program Files (x86)\Steam", "C:\Program Files\Steam"
    foreach ($lib in $libs | Select-Object -Unique) {
        $p = Join-Path $lib "steamapps\common\Clean Start"
        if (Test-Path (Join-Path $p "Clean Start.exe")) { return $p }
    }
    return $null
}

function Resolve-GameDir([string]$GameDir) {
    if (-not $GameDir) { $GameDir = Find-Game }
    if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir "Clean Start.exe"))) {
        Write-Host "Не нашёл игру Clean Start." -ForegroundColor Red
        Write-Host "Укажите папку вручную: перетащите папку игры на файл 'Установить.bat'."
        Write-Host "(Steam -> Clean Start -> Управление -> Просмотреть локальные файлы)"
        exit 1
    }
    if (Get-Process -Name "Clean Start" -ErrorAction SilentlyContinue) {
        Write-Host "Закройте игру и запустите снова." -ForegroundColor Red
        exit 1
    }
    return $GameDir.TrimEnd('\')
}

function Get-Sha([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Read-HashList([string]$Path) {
    $h = [ordered]@{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line.Trim()) { $hash, $rel = $line -split "  ", 2; $h[$rel] = $hash }
    }
    return $h
}

function Apply-CsPatch([string]$Source, [string]$PatchFile, [string]$Output) {
    $pf = [IO.File]::OpenRead($PatchFile)
    $gz = New-Object IO.Compression.GZipStream($pf, [IO.Compression.CompressionMode]::Decompress)
    $ms = New-Object IO.MemoryStream
    $gz.CopyTo($ms); $gz.Dispose(); $pf.Dispose()
    $ms.Position = 0
    $r = New-Object IO.BinaryReader($ms)
    $magic = [Text.Encoding]::ASCII.GetString($r.ReadBytes(10))
    if ($magic -ne "CSRUPATCH1") { throw "Неверный файл патча: $PatchFile" }
    [void]$r.ReadUInt64(); [void]$r.ReadBytes(32)
    $count = $r.ReadUInt32()
    $src = [IO.File]::OpenRead($Source)
    $out = [IO.File]::Create($Output)
    $buf = New-Object byte[] (1MB)
    try {
        for ($i = 0; $i -lt $count; $i++) {
            $op = $r.ReadByte()
            if ($op -eq 1) {
                $off = [int64]$r.ReadUInt64(); $len = [int64]$r.ReadUInt64()
                [void]$src.Seek($off, [IO.SeekOrigin]::Begin)
                while ($len -gt 0) {
                    $n = $src.Read($buf, 0, [int][Math]::Min($buf.Length, $len))
                    if ($n -le 0) { throw "Исходный файл короче ожидаемого" }
                    $out.Write($buf, 0, $n); $len -= $n
                }
            } elseif ($op -eq 2) {
                $len = [int]$r.ReadUInt64()
                $out.Write($r.ReadBytes($len), 0, $len)
            } else { throw "Повреждённый патч" }
        }
    } finally { $out.Dispose(); $src.Dispose(); $r.Dispose() }
}
