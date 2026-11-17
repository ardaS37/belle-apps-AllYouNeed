# QML/JS dosyalarindaki kullaniciya gorunen Turkce metinleri qsTr("...") ile sarar.
# Kullanim:  .\dil_sar.ps1 -Uygulama ..\WhatsE6            (yalnizca rapor)
#            .\dil_sar.ps1 -Uygulama ..\WhatsE6 -Uygula    (dosyalari degistirir)
# ListElement icindekiler QT_TR_NOOP("...") olur; kullanildiklari yerde qsTr(ad) elle eklenmeli (raporda "LISTE").
# Karsilastirmada kullanilan metinler sarilmaz, raporda "KARSILASTIRMA" olarak listelenir.
param([Parameter(Mandatory = $true)][string]$Uygulama, [switch]$Uygula, [string[]]$Atla = @())

$ErrorActionPreference = "Stop"
$kok = (Resolve-Path $Uygulama).Path
$dosyalar = Get-ChildItem $kok -Recurse -File -Include *.qml, *.js | Where-Object {
    $_.FullName -notmatch '\\(build|release|debug|dil)\\' -and ($Atla -notcontains $_.Name)
}

$trHarf = '[çğışöüÇĞİŞÖÜ]'
function MetinMi([string]$s) {
    if ($s.Length -lt 2) { return $false }
    if ($s -notmatch '[A-Za-zçğışöüÇĞİŞÖÜ]') { return $false }
    if ($s -match '://|^#|^qrc:|^file:|\.(png|jpg|jpeg|gif|svg|qml|js|txt|ini|mp3|wav|html?)$') { return $false }
    if ($s -match '^[\w\-\./:%?=&]+$' -and $s -cnotmatch $trHarf -and $s -cnotmatch '^[A-ZÇĞİÖŞÜ][a-zçğışöü]') { return $false }
    if ($s -match '^(hh|HH|dd|MM|yyyy|mm|ss)[\s:.\-/hdMmsy]*$') { return $false }
    if ($s -cmatch $trHarf) { return $true }
    if ($s -match '\s' -and $s -match '[a-zA-Z]{2}') { return $true }
    if ($s -cmatch '^[A-ZÇĞİÖŞÜ][a-zçğışöü]{2,}') { return $true }
    return $false
}

$rapor = New-Object System.Collections.Generic.List[string]
$toplam = 0
foreach ($f in $dosyalar) {
    $satirlar = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8) -split "`n", -1
    $degisti = $false
    $blokYorum = $false
    $listeDerinlik = -1   # ListElement { ... } icindeyken suslu derinligi
    $derinlik = 0
    for ($n = 0; $n -lt $satirlar.Count; $n++) {
        $line = $satirlar[$n]
        if ($line -match '^\s*import\b') { continue }
        if ($line -match 'ListElement\s*\{') { $listeDerinlik = $derinlik }
        $out = New-Object Text.StringBuilder
        $i = 0
        $yorum = $false
        while ($i -lt $line.Length) {
            $c = $line[$i]
            if ($blokYorum) {
                if ($c -eq '*' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '/') { $blokYorum = $false; [void]$out.Append('*/'); $i += 2; continue }
                [void]$out.Append($c); $i++; continue
            }
            if ($c -eq '/' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '/') { [void]$out.Append($line.Substring($i)); break }
            if ($c -eq '/' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '*') { $blokYorum = $true; [void]$out.Append('/*'); $i += 2; continue }
            if ($c -eq '/') {
                # regex ifadesi (/.../): onceki anlamli karakter operator ya da ayirac ise; icindeki tirnaklar dize sayilmaz
                $onceki = $out.ToString().TrimEnd()
                if ($onceki -eq "" -or $onceki -match '[\(,=:\[!&|?{};+\-*%<>~^]$' -or $onceki -match '\b(return|typeof|case|in)$') {
                    $j = $i + 1; $sinif = $false
                    while ($j -lt $line.Length) {
                        $cj = $line[$j]
                        if ($cj -eq '\') { $j += 2; continue }
                        if ($cj -eq '[') { $sinif = $true } elseif ($cj -eq ']') { $sinif = $false } elseif ($cj -eq '/' -and -not $sinif) { break }
                        $j++
                    }
                    if ($j -lt $line.Length) { [void]$out.Append($line.Substring($i, $j - $i + 1)); $i = $j + 1; continue }
                }
            }
            if ($c -eq '{') { $derinlik++ }
            if ($c -eq '}') { $derinlik--; if ($listeDerinlik -ge 0 -and $derinlik -le $listeDerinlik) { $listeDerinlik = -1 } }
            if ($c -eq "'") {
                # tek tirnakli dizeleri oldugu gibi gec
                $j = $i + 1
                while ($j -lt $line.Length -and $line[$j] -ne "'") { if ($line[$j] -eq '\') { $j++ }; $j++ }
                [void]$out.Append($line.Substring($i, [Math]::Min($j + 1, $line.Length) - $i)); $i = $j + 1; continue
            }
            if ($c -ne '"') { [void]$out.Append($c); $i++; continue }
            # cift tirnakli dize
            $j = $i + 1
            while ($j -lt $line.Length -and $line[$j] -ne '"') { if ($line[$j] -eq '\') { $j++ }; $j++ }
            if ($j -ge $line.Length) { [void]$out.Append($line.Substring($i)); break }
            $icerik = $line.Substring($i + 1, $j - $i - 1)
            $once = $out.ToString()
            $sonra = $line.Substring($j + 1)
            $karar = "sar"
            if (-not (MetinMi $icerik)) { $karar = "gec" }
            elseif ($once -match '(qsTr|QT_TR_NOOP|qsTranslate|QT_TRANSLATE_NOOP)\s*\(\s*$') { $karar = "gec" }
            elseif ($sonra -match '^\s*:' -and $once -match '[{,]\s*$') { $karar = "gec" }
            elseif ($once -match '(===|!==|==|!=)\s*$' -or $sonra -match '^\s*(===|!==|==|!=)' -or $once -match '\bcase\s*$') { $karar = "karsilastirma" }
            elseif ($once -match '(setting|setSetting|ayar|ayarYaz|value|setValue|executeSql|indexOf|split|replace|match|test|search|lastIndexOf|startsWith|endsWith|charAt|getElementById|querySelector|setRequestHeader|request)\s*\(\s*$') { $karar = "gec" }
            elseif ($once -match '(console\.log|notify\.log|\blog|\bgunluk\.yaz|\bkayit|\biz)\s*\(.*$' -and $once -notmatch '(showToast|toast)') { $karar = "gec" }
            elseif ($once -match '\b(source|url|icon|ikon|image|resim|family|color|renk|anchors\.\w+|objectName|state|name)\s*:\s*$') { $karar = "gec" }
            if ($karar -eq "sar") {
                if ($listeDerinlik -ge 0) {
                    [void]$out.Append('QT_TR_NOOP("' + $icerik + '")')
                    $rapor.Add("LISTE        $($f.Name):$($n+1)  `"$icerik`"")
                } else {
                    [void]$out.Append('qsTr("' + $icerik + '")')
                }
                $toplam++; $degisti = $true
            } else {
                if ($karar -eq "karsilastirma") { $rapor.Add("KARSILASTIRMA $($f.Name):$($n+1)  `"$icerik`"") }
                [void]$out.Append('"' + $icerik + '"')
            }
            $i = $j + 1
        }
        $satirlar[$n] = $out.ToString()
    }
    if ($degisti -and $Uygula) {
        [IO.File]::WriteAllText($f.FullName, ($satirlar -join "`n"), (New-Object Text.UTF8Encoding($false)))
    }
}
$rapor | Sort-Object | ForEach-Object { $_ }
"TOPLAM sarilan: $toplam  (uygulandi: $([bool]$Uygula))"
